import Foundation

// ============================================================================
//  Timer Deck — 计时器操作
//  所有改动都经过这里，对应浏览器版的 actions.js
// ============================================================================

enum Actions {
    private static var store: Store { Store.shared }
    private static var timers: [TimerItem] { store.timers }

    private static func replace(_ id: String, _ fn: (TimerItem) -> TimerItem) {
        store.setTimers(timers.map { $0.id == id ? fn($0) : $0 })
    }

    /// 按一下：进行中 → 暂停；其余 → 从原位开始
    static func toggle(_ id: String) {
        let now = Engine.nowMS()
        replace(id) { t in
            var copy = t
            let v = Engine.view(t, now: now)
            if v.status == .running {
                copy.status = .paused
                copy.remaining = v.remaining
                copy.endsAt = nil
            } else {
                let remaining = (v.status == .finished || v.remaining <= 0) ? t.duration : v.remaining
                copy.status = .running
                copy.remaining = remaining
                copy.endsAt = now + remaining
                copy.finishedAt = nil
                copy.rangAt = nil
            }
            return copy
        }
    }

    static func reset(_ id: String) {
        replace(id) { t in
            var copy = t
            copy.status = .idle
            copy.remaining = t.duration
            copy.endsAt = nil
            copy.finishedAt = nil
            copy.rangAt = nil
            return copy
        }
    }

    struct Removed {
        var timer: TimerItem
        var index: Int
    }

    @discardableResult
    static func remove(_ id: String) -> Removed? {
        let list = timers
        guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        let gone = list[index]
        var next = list
        next.remove(at: index)
        store.setTimers(next)
        return Removed(timer: gone, index: index)
    }

    static func restore(_ removed: Removed?) {
        guard let r = removed else { return }
        var list = timers
        let at = max(0, min(r.index, list.count))
        list.insert(r.timer, at: at)
        store.setTimers(list)
    }

    @discardableResult
    static func removeMany(_ ids: [String]) -> [Removed] {
        guard !ids.isEmpty else { return [] }
        let list = timers
        var gone: [Removed] = []
        var kept: [TimerItem] = []
        for (i, t) in list.enumerated() {
            if ids.contains(t.id) { gone.append(Removed(timer: t, index: i)) }
            else { kept.append(t) }
        }
        guard !gone.isEmpty else { return [] }
        store.setTimers(kept)
        return gone
    }

    static func restoreMany(_ entries: [Removed]) {
        guard !entries.isEmpty else { return }
        var list = timers
        for e in entries.sorted(by: { $0.index < $1.index }) {
            let at = max(0, min(e.index, list.count))
            list.insert(e.timer, at: at)
        }
        store.setTimers(list)
    }

    static func finishedIds(now: Double) -> [String] {
        timers.filter { Engine.view($0, now: now).status == .finished }.map { $0.id }
    }

    static func rename(_ id: String, to name: String) {
        replace(id) { t in
            var copy = t
            copy.name = name
            return copy
        }
    }

    @discardableResult
    static func duplicate(_ id: String) -> String? {
        guard let src = timers.first(where: { $0.id == id }) else { return nil }
        var copy = src
        copy.id = Engine.uid()
        copy.status = .idle
        copy.remaining = src.duration
        copy.endsAt = nil
        copy.finishedAt = nil
        copy.rangAt = nil
        copy.createdAt = Engine.nowMS()
        store.setTimers(timers + [copy])
        return copy.id
    }

    @discardableResult
    static func add(_ timer: TimerItem) -> String {
        store.setTimers(timers + [timer])
        return timer.id
    }

    /// 建立一个新的计时器，而且立即开始倒数。
    /// 对应浏览器版 popup.js 的 save()：新计时器不用再按一次开始。
    @discardableResult
    static func create(
        name: String,
        seconds: Double,
        accent: String,
        isRepeating: Bool,
        notify: Bool,
        sound: String
    ) -> String {
        let stamp = Engine.nowMS()
        let fresh = Engine.started(
            Engine.makeTimer(
                name: name,
                seconds: seconds,
                accent: accent,
                isRepeating: isRepeating,
                notify: notify,
                sound: sound
            ),
            now: stamp
        )
        let id = add(fresh)
        // 让界面立刻用同一个时间戳重算 —— 否则第一帧会读到上一秒的旧时间，
        // 倒数就会由「时长 + 1 秒」开始。见 Engine.view 的上限保护。
        store.refreshNow(to: stamp)
        return id
    }

    /// 铃声是全局的一件事，改一次套用到所有计时器
    static func setSoundForAll(_ tone: String) {
        let t = Engine.coerceSound(tone, fallback: Engine.defaultSound)
        store.setTimers(timers.map { item in
            var copy = item
            copy.sound = t
            return copy
        })
        store.updateSettings { $0.sound = t }
    }

    static func pauseAll() {
        let now = Engine.nowMS()
        store.setTimers(timers.map { t in
            guard t.status == .running else { return t }
            var copy = t
            let v = Engine.view(t, now: now)
            copy.status = .paused
            copy.remaining = v.remaining
            copy.endsAt = nil
            return copy
        })
    }

    static func resumeAll() {
        let now = Engine.nowMS()
        store.setTimers(timers.map { t in
            guard t.status == .paused || t.status == .idle else { return t }
            var copy = t
            let remaining = t.status == .idle ? t.duration : t.remaining
            copy.status = .running
            copy.remaining = remaining
            copy.endsAt = now + remaining
            copy.finishedAt = nil
            copy.rangAt = nil
            return copy
        })
    }

    // ------------------------------------------------------------- 摘要 --
    struct Summary {
        var running = 0
        var paused = 0
        var finished = 0
        var idle = 0
        var total: Int { running + paused + finished + idle }
    }

    static func summary(now: Double) -> Summary {
        var s = Summary()
        for t in timers {
            switch Engine.view(t, now: now).status {
            case .running: s.running += 1
            case .paused: s.paused += 1
            case .finished: s.finished += 1
            case .idle: s.idle += 1
            }
        }
        return s
    }
}
