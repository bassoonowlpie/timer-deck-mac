import Foundation
import Combine

// ============================================================================
//  Timer Deck — 储存层
//  单一 JSON 档 ＋ 每秒一次的时间推进。等价于浏览器版的 store.js + background.js
// ============================================================================

final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var timers: [TimerItem] = []
    @Published private(set) var settings = Settings()
    /// 每秒更新一次，UI 靠它重绘倒数
    @Published private(set) var now: Double = Engine.nowMS()

    private var ticker: Timer?
    private var seenAlerts: [String: Double] = [:]
    private let dirURL: URL
    private let fileURL: URL

    /// 存档资料夹的实际路径（开发工具会用到）
    static var dataDirPath: String { shared.dirURL.path }

    private init() {
        // 开发用途：设定环境变数 TIMERDECK_DATA_DIR 可以把存档写到别处。
        // 自测 / 渲染预览都走这个，免得动到使用者真正的存档。
        // （正常从 Finder 或菜单栏启动时不会有这个变数）
        if let override = ProcessInfo.processInfo.environment["TIMERDECK_DATA_DIR"],
           !override.isEmpty {
            dirURL = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            dirURL = base.appendingPathComponent("TimerDeck", isDirectory: true)
        }
        fileURL = dirURL.appendingPathComponent("deck.json")
        load()
        I18n.setLang(settings.lang)
    }

    // ------------------------------------------------------------- 读写 --
    func load() {
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let deck = try? JSONDecoder().decode(DeckFile.self, from: data) else { return }
        timers = deck.timers
        settings = normalize(deck.settings, timers: &timers)
    }

    func save() {
        let deck = DeckFile(timers: timers, settings: settings)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        guard let data = try? enc.encode(deck) else { return }
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 把存档清洗一遍（对应 store.js 的 normalize）
    private func normalize(_ raw: Settings, timers: inout [TimerItem]) -> Settings {
        var s = raw
        s.sound = Engine.coerceSound(s.sound, fallback: "alarm")
        s.recentNames = s.recentNames
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(30)) }
            .prefix(10)
            .map { $0 }
        s.recentDurations = s.recentDurations
            .filter { $0.isFinite && $0 >= 1 && $0 <= 36000 }
            .prefix(6)
            .map { $0 }
        s.hiddenNames = s.hiddenNames
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(30)) }
            .prefix(30)
            .map { $0 }

        // 铃声版本升级：旧的存档一次性改用新的预设
        if raw.soundVersion != Engine.soundVersion {
            s.sound = Engine.defaultSound
            s.soundVersion = Engine.soundVersion
            timers = timers.map { t in
                var copy = t
                if copy.sound != "none" { copy.sound = Engine.defaultSound }
                copy.sound = Engine.coerceSound(copy.sound, fallback: Engine.defaultSound)
                return copy
            }
        }
        return s
    }

    // -------------------------------------------------------------- 生命周期 --
    func startTicking() {
        guard ticker == nil else { return }
        tick()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        let current = Engine.nowMS()
        now = current

        let result = Engine.reconcile(timers, now: current)
        if result.changed {
            timers = result.timers
            save()
        }
        processAlerts(result.timers, now: current)
    }

    // ------------------------------------------------------------- 提醒 --
    private func processAlerts(_ list: [TimerItem], now: Double) {
        let pending = Engine.pendingAlerts(list, seen: seenAlerts, now: now)
        for entry in pending.stale {
            seenAlerts[entry.timer.id] = entry.stamp
        }
        guard !pending.due.isEmpty else { return }

        for entry in pending.due {
            seenAlerts[entry.timer.id] = entry.stamp
        }

        // 一次只响一个铃声；通知则逐个发
        if let first = pending.due.first(where: { $0.timer.sound != "none" }) {
            SoundPlayer.shared.play(first.timer.sound)
        }
        for entry in pending.due where entry.timer.notify {
            let name = entry.timer.name.isEmpty ? I18n.t("defaultName") : entry.timer.name
            Notifier.shared.fire(title: I18n.t("notifTitle", ["name": name]))
        }
    }

    // ------------------------------------------------------------- 变更 --
    func setTimers(_ next: [TimerItem]) {
        timers = next
        save()
        objectWillChange.send()
    }

    func updateSettings(_ mutate: (inout Settings) -> Void) {
        var s = settings
        mutate(&s)
        settings = s
        I18n.setLang(s.lang)
        save()
    }

    func rememberName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        updateSettings { s in
            var list = s.recentNames.filter { $0 != trimmed }
            list.insert(String(trimmed.prefix(30)), at: 0)
            s.recentNames = Array(list.prefix(10))
        }
    }

    /// 只记自订时长（预设模板不记）
    func rememberDuration(seconds: Double) {
        guard seconds >= 1, seconds <= 36000 else { return }
        let presetSeconds = Engine.presetsMin.map { Double($0) * 60 }
        if presetSeconds.contains(seconds) { return }
        updateSettings { s in
            var list = s.recentDurations.filter { $0 != seconds }
            list.insert(seconds, at: 0)
            s.recentDurations = Array(list.prefix(6))
        }
    }

    /// 立刻把「现在」对齐到真实时间。
    /// 建立计时器之后会传入当时用的那个时间戳，让画面第一帧算出来刚好等于时长，
    /// 而不会因为读到上一秒的旧时间而多出一秒。
    func refreshNow(to stamp: Double? = nil) {
        now = stamp ?? Engine.nowMS()
    }

    // -------------------------------------------------------- 名称建议 --
    /// 从表单的名片列里删掉一个建议名称。
    /// 删掉就是删掉 —— 同时移出「最近使用」并记入隐藏清单，之后不会再冒出来。
    func removeNameSuggestion(_ name: String) {
        updateSettings { s in
            s.recentNames.removeAll { $0 == name }
            if !s.hiddenNames.contains(name) {
                s.hiddenNames.append(name)
            }
        }
    }

    /// 把删掉的建议名称全部收回来
    func clearHiddenNames() {
        guard !settings.hiddenNames.isEmpty else { return }
        updateSettings { $0.hiddenNames = [] }
    }
}
