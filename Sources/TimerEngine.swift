import Foundation

// ============================================================================
//  Timer Deck — 引擎
//  纯逻辑，不碰 UI。逐一对应浏览器版的 engine.js，行为保持一致。
// ============================================================================

enum Engine {
    static let minute: Double = 60 * 1000
    /// 「即将结束」的判定门槛
    static let soonMS: Double = 60 * 1000
    /// 睡过头的完成就不响了
    static let alertGraceMS: Double = 10 * 60 * 1000
    /// 自订时长上限十分钟…不对，是十小时
    static let maxMin = 600
    static let maxSec = maxMin * 60

    static let accents = ["#3D7BFF", "#5BCFC5", "#FFA94D", "#FF6B6B", "#8A8A8A"]
    static let presetsMin = [1, 15, 30, 60]
    static let soundTones = ["alarm", "chime", "bell", "ping"]
    static let defaultSound = "alarm"
    /// 提一次版本号，让旧的存档一次性改用新的预设铃声
    static let soundVersion = 2

    // ------------------------------------------------------------- 基本 --
    static func coerceSound(_ value: String?, fallback: String) -> String {
        guard let v = value, !v.isEmpty else { return fallback }
        if v == "none" || soundTones.contains(v) { return v }
        return fallback
    }

    static func clampMinutes(_ n: Double) -> Double {
        guard n.isFinite else { return 1 }
        return max(1, min(Double(maxMin), n.rounded()))
    }

    static func clampSeconds(_ n: Double) -> Double {
        guard n.isFinite else { return 60 }
        return max(1, min(Double(maxSec), n.rounded()))
    }

    // ----------------------------------------------------------------- id --
    private static var seq = 0
    static func uid() -> String {
        seq += 1
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let s = String(seq, radix: 36)
        let r = String(Int.random(in: 0..<1296), radix: 36)
        return "t" + stamp + s + r
    }

    // ------------------------------------------------------------ 工厂 --
    static func makeTimer(
        name: String = "",
        seconds: Double? = nil,
        minutes: Double? = nil,
        accent: String? = nil,
        isRepeating: Bool = false,
        notify: Bool = true,
        sound: String? = nil,
        id: String? = nil
    ) -> TimerItem {
        let secs: Double
        if let s = seconds {
            secs = clampSeconds(s)
        } else {
            secs = clampMinutes(minutes ?? 10) * 60
        }
        let duration = max(1000, secs * 1000)
        return TimerItem(
            id: id ?? uid(),
            name: name,
            duration: duration,
            remaining: duration,
            endsAt: nil,
            status: .idle,
            accent: accent ?? accents[0],
            isRepeating: isRepeating,
            notify: notify,
            sound: coerceSound(sound, fallback: defaultSound),
            createdAt: nowMS()
        )
    }

    /// 全新的计时器一建好就开始跑 —— 对应浏览器版 popup.js 的 save()。
    /// 想停下来按一下进度环即可。
    static func started(_ t: TimerItem, now: Double) -> TimerItem {
        var copy = t
        copy.status = .running
        copy.remaining = copy.duration
        copy.endsAt = now + copy.duration
        copy.finishedAt = nil
        copy.rangAt = nil
        return copy
    }

    // -------------------------------------------------------------- 时间 --
    static func nowMS() -> Double {
        Date().timeIntervalSince1970 * 1000
    }

    // ------------------------------------------------------------ 推导 --
    /// 求出某个时刻的实际状态，绝不写回。
    static func view(_ t: TimerItem, now: Double) -> TimerView {
        var status = t.status
        var remaining = t.remaining

        if status == .running {
            if let endsAt = t.endsAt {
                // 上限就是原始时长。`now` 每秒才更新一次，刚建立计时器时
                // 画面可能读到稍微过期的时间，算出来会多过一秒。
                // 这里卡住上限，倒数就永远不会由「比时长多一秒」开始。
                remaining = min(endsAt - now, t.duration)
                if remaining <= 0 {
                    remaining = 0
                    status = .finished
                }
            } else {
                status = .paused
            }
        }

        if status == .finished { remaining = 0 }
        // 剩余时间在任何情况下都不该多过原本时长
        remaining = min(remaining, max(1, t.duration))
        let total = max(1, t.duration)
        let progress = 1 - max(0, min(1, remaining / total))

        // 完成时若没人来得及写回，endsAt 本身就是完成时刻
        let doneAt = t.finishedAt ?? (status == .finished ? t.endsAt : nil)

        return TimerView(
            id: t.id,
            name: t.name,
            accent: t.accent,
            status: status,
            remaining: max(0, remaining),
            progress: status == .idle ? 0 : progress,
            endsAt: t.endsAt,
            finishedAt: doneAt,
            duration: t.duration,
            isRepeating: t.isRepeating
        )
    }

    struct ReconcileResult {
        var timers: [TimerItem]
        var changed: Bool
        var justFinished: [TimerItem]
    }

    /// 把流逝的时间折回储存状态，返回全新阵列。
    static func reconcile(_ timers: [TimerItem], now: Double) -> ReconcileResult {
        var changed = false
        var justFinished: [TimerItem] = []

        let next = timers.map { t -> TimerItem in
            guard t.status == .running, let endsAt = t.endsAt else { return t }
            let remaining = endsAt - now
            if remaining > 0 { return t }
            changed = true

            if t.isRepeating {
                var lap = t
                lap.finishedAt = now
                lap.rangAt = now
                justFinished.append(lap)

                var re = t
                re.endsAt = now + t.duration
                re.remaining = t.duration
                re.finishedAt = nil
                re.rangAt = now
                return re
            }

            var done = t
            done.status = .finished
            done.remaining = 0
            done.endsAt = nil
            done.finishedAt = now
            justFinished.append(done)
            return done
        }

        return ReconcileResult(timers: next, changed: changed, justFinished: justFinished)
    }

    // ------------------------------------------------------------ 提醒 --
    /// 这个计时器「最后一次跨过零」的时刻——不管当时有没有人被开启。
    static func finishStamp(_ t: TimerItem, now: Double) -> Double? {
        if t.isRepeating {
            if let rang = t.rangAt { return rang }
            if let endsAt = t.endsAt, endsAt <= now { return endsAt }
            return nil
        }
        if t.status == .running {
            if let endsAt = t.endsAt, endsAt <= now { return endsAt }
            return nil
        }
        if t.status == .finished { return t.finishedAt ?? t.endsAt }
        return nil
    }

    struct Pending {
        var due: [(timer: TimerItem, stamp: Double)] = []
        var stale: [(timer: TimerItem, stamp: Double)] = []
    }

    /// 哪些该现在响、哪些已经过期太久（安静处理）。
    /// `seen` 记录每个计时器已经响过的时刻，确保同一圈只响一次。
    static func pendingAlerts(_ timers: [TimerItem], seen: [String: Double], now: Double) -> Pending {
        var out = Pending()
        for t in timers {
            guard let stamp = finishStamp(t, now: now) else { continue }
            if let already = seen[t.id], already == stamp { continue }
            if now - stamp > alertGraceMS {
                out.stale.append((t, stamp))
            } else {
                out.due.append((t, stamp))
            }
        }
        return out
    }

    // ------------------------------------------------------------ 格式化 --
    private static func pad2(_ n: Int) -> String {
        (n < 10 ? "0" : "") + String(n)
    }

    /// 01:30 / 1:05:00
    static func formatClock(_ ms: Double) -> String {
        let total = max(0, Int(ceil(ms / 1000)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h):\(pad2(m)):\(pad2(s))" }
        return "\(pad2(m)):\(pad2(s))"
    }

    /// 「3 分鐘」/「1 分 30 秒」/「15 秒」
    static func formatSpan(_ ms: Double, lang: String) -> String {
        let total = Int((ms / 1000).rounded())
        let m = total / 60
        let s = total % 60
        if lang == "en" {
            if m == 0 { return "\(s)s" }
            return s == 0 ? "\(m) min" : "\(m)m \(s)s"
        }
        if m == 0 { return "\(s) 秒" }
        return s == 0 ? "\(m) 分鐘" : "\(m) 分 \(s) 秒"
    }

    /// 14:05
    static func clockTime(_ ts: Double, lang: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang == "en" ? "en_GB" : "zh_HK")
        f.dateFormat = "HH:mm"
        return f.string(from: Date(timeIntervalSince1970: ts / 1000))
    }

    /// 最快到期的那一刻（没有就 nil）
    static func dueAt(_ timers: [TimerItem]) -> Double? {
        var soonest: Double?
        for t in timers where t.status == .running {
            guard let endsAt = t.endsAt else { continue }
            if soonest == nil || endsAt < soonest! { soonest = endsAt }
        }
        return soonest
    }

    /// 菜单栏图示旁边要显示的一格（对应一个进行中的计时器）。
    struct MenuBarSegment {
        let name: String
        let text: String
        let accentHex: String
    }

    /// 菜单栏图示旁边要显示的文字。
    ///
    /// - **所有**进行中的计时器都会显示，各自上自己的 accent 色
    /// - 每一格都含 name + 时间（如「煮麵 12:34」），由 UI 决定怎么排
    /// - 按剩余时间升序（最快到期的排最前）
    /// - 一个都没有在跑 → 空阵列（只留下图示）
    static func menuBarSegments(_ timers: [TimerItem], now: Double) -> [MenuBarSegment] {
        var running: [(remaining: Double, segment: MenuBarSegment)] = []

        for t in timers {
            let v = view(t, now: now)
            guard v.status == .running else { continue }
            let seg = MenuBarSegment(name: t.name, text: formatClock(v.remaining), accentHex: t.accent)
            running.append((v.remaining, seg))
        }

        running.sort { $0.remaining < $1.remaining }
        return running.map { $0.segment }
    }

    /// 环形进度条的色调
    static func tone(for v: TimerView) -> RingTone {
        switch v.status {
        case .finished: return .done
        case .paused: return .paused
        case .idle: return .idle
        case .running: return v.remaining <= soonMS ? .soon : .run
        }
    }
}
