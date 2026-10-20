import Foundation

// ============================================================================
//  SelfTest — 逻辑自测
//  以 `TimerDeck --selftest` 执行，验证引擎逻辑与浏览器版行为一致。
// ============================================================================

enum SelfTest {

    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--selftest") else { return false }

        var pass = 0
        var fail = 0
        func check(_ name: String, _ ok: Bool) {
            if ok { pass += 1; print("  ✓ \(name)") }
            else { fail += 1; print("  ✗ \(name)") }
        }

        let now = 1_700_000_000_000.0

        print("\n=== 1. 建立计时器 ===")
        let t = Engine.makeTimer(name: "煮麵", seconds: 90)
        check("duration = 90 秒", t.duration == 90_000)
        check("remaining 同上", t.remaining == 90_000)
        check("初始状态 idle", t.status == .idle)
        check("预设铃声 alarm", t.sound == "alarm")
        check("预设主题色", t.accent == "#3D7BFF")
        check("预设会通知", t.notify == true)
        check("预设不重复", t.isRepeating == false)

        print("\n=== 2. 数值夹挤 ===")
        check("clampSeconds(0) → 1", Engine.clampSeconds(0) == 1)
        check("clampSeconds(99999) → 36000", Engine.clampSeconds(99999) == 36_000)
        check("clampSeconds(30) → 30", Engine.clampSeconds(30) == 30)
        check("clampMinutes(0) → 1", Engine.clampMinutes(0) == 1)
        check("clampMinutes(999) → 600", Engine.clampMinutes(999) == 600)
        check("coerceSound(\"jazz\") → alarm", Engine.coerceSound("jazz", fallback: "alarm") == "alarm")
        check("coerceSound(\"none\") → none", Engine.coerceSound("none", fallback: "alarm") == "none")

        print("\n=== 3. 即时状态推导 ===")
        var run = t
        run.status = .running
        run.endsAt = now + 60_000
        let v1 = Engine.view(run, now: now)
        check("进行中剩余 60 秒", v1.remaining == 60_000)
        check("状态仍为 running", v1.status == .running)
        check("进度约 1/3", abs(v1.progress - (1.0 / 3.0)) < 0.01)

        let v2 = Engine.view(run, now: now + 61_000)
        check("过期后状态 finished", v2.status == .finished)
        check("过期后剩余 0", v2.remaining == 0)

        var noEnd = t
        noEnd.status = .running
        noEnd.endsAt = nil
        check("running 但无 endsAt → paused", Engine.view(noEnd, now: now).status == .paused)

        print("\n=== 4. 时间折回 ===")
        let r1 = Engine.reconcile([run], now: now + 61_000)
        check("有变动", r1.changed == true)
        check("状态写成 finished", r1.timers[0].status == .finished)
        check("endsAt 清空", r1.timers[0].endsAt == nil)
        check("finishedAt 盖章", r1.timers[0].finishedAt == now + 61_000)
        check("justFinished 有 1 笔", r1.justFinished.count == 1)

        var rep = t
        rep.isRepeating = true
        rep.status = .running
        rep.endsAt = now + 60_000
        let r2 = Engine.reconcile([rep], now: now + 61_000)
        check("重复计时器仍在跑", r2.timers[0].status == .running)
        check("重新设定 endsAt", r2.timers[0].endsAt == now + 61_000 + 90_000)
        check("这一圈有盖章 rangAt", r2.timers[0].rangAt == now + 61_000)

        print("\n=== 5. 提醒去重 ===")
        let fresh = Engine.reconcile([run], now: now + 61_000).timers
        let p1 = Engine.pendingAlerts(fresh, seen: [:], now: now + 61_000)
        check("首次应响", p1.due.count == 1)
        check("不是过期", p1.stale.count == 0)

        let stamp = Engine.finishStamp(fresh[0], now: now + 61_000)!
        let p2 = Engine.pendingAlerts(fresh, seen: [fresh[0].id: stamp], now: now + 61_000)
        check("同一圈不再响", p2.due.count == 0)

        let p3 = Engine.pendingAlerts(fresh, seen: [:], now: now + 61_000 + 11 * 60_000)
        check("超过 10 分钟归为过期", p3.stale.count == 1)
        check("过期就不响", p3.due.count == 0)

        print("\n=== 6. 格式化 ===")
        check("01:30", Engine.formatClock(90_000) == "01:30")
        check("00:09", Engine.formatClock(9_000) == "00:09")
        check("1:05:00", Engine.formatClock(3_900_000) == "1:05:00")
        check("0 秒不出现负号", Engine.formatClock(-5_000) == "00:00")
        check("\"1 分 30 秒\"", Engine.formatSpan(90_000, lang: "zh-Hant") == "1 分 30 秒")
        check("\"3 分鐘\"", Engine.formatSpan(180_000, lang: "zh-Hant") == "3 分鐘")
        check("\"45 秒\"", Engine.formatSpan(45_000, lang: "zh-Hant") == "45 秒")
        check("\"1m 30s\"", Engine.formatSpan(90_000, lang: "en") == "1m 30s")

        print("\n=== 7. 選單列顯示 ===")
        var a = Engine.makeTimer(name: "煮麵", seconds: 300)
        a.status = .running; a.endsAt = now + 300_000
        var b = Engine.makeTimer(name: "小睡", seconds: 30)
        b.status = .running; b.endsAt = now + 30_000
        check("没有进行中 → 空", Engine.menuBarSegments([t], now: now).isEmpty)
        check("只有一个 → 显示剩余时间",
              Engine.menuBarSegments([a], now: now).map(\.text) == ["05:00"])
        check("超过一小时 → 1:15:00",
              Engine.menuBarSegments(
                [Engine.started(Engine.makeTimer(name: "长", seconds: 4500), now: now)], now: now
              ).map(\.text) == ["1:15:00"])
        let segs = Engine.menuBarSegments([a, b], now: now)
        check("两个 → 全部显示，按剩余升序", segs.map(\.text) == ["00:30", "05:00"])
        check("各自带 accent 色", segs.first?.accentHex == b.accent && segs.last?.accentHex == a.accent)
        check("各自带计时器名", segs.map(\.name) == [b.name, a.name])
        check("一个在跑 + 一个暂停 → 只显示跑的",
              Engine.menuBarSegments([a, t], now: now).map(\.text) == ["05:00"])

        print("\n=== 8. 铃声版本迁移 ===")
        check("SOUND_VERSION = 2", Engine.soundVersion == 2)
        check("预设铃声 alarm", Engine.defaultSound == "alarm")

        print("\n=== 9. 双语字串 ===")
        I18n.setLang("zh-Hant")
        check("繁中 newTimer", I18n.t("newTimer") == "新增計時器")
        check("繁中带变数", I18n.t("statusRunningOnly", ["r": "3"]) == "3 個進行中")
        I18n.setLang("en")
        check("英文 newTimer", I18n.t("newTimer") == "New timer")
        check("英文带变数", I18n.t("statusRunningOnly", ["r": "3"]) == "3 running")
        I18n.setLang("zh-Hant")
        check("时长组合", I18n.durationLabel(seconds: 4500) == "1 小時 15 分鐘")

        print("\n=== 10. 新建立即开始 ===")
        let fresh0 = Engine.started(Engine.makeTimer(name: "煮麵", seconds: 90), now: now)
        let sv = Engine.view(fresh0, now: now)
        check("状态 running", sv.status == .running)
        check("剩余等于总时长", sv.remaining == 90_000)
        check("endsAt = now + 时长", fresh0.endsAt == now + 90_000)
        check("finishedAt 已清空", fresh0.finishedAt == nil)
        check("时间到自动转 finished", Engine.view(fresh0, now: now + 91_000).status == .finished)
        check("idle 的原件不受影响", Engine.makeTimer(seconds: 90).status == .idle)

        print("\n=== 11. 名称建议隐藏（存档往返）===")
        check("内建建议含「泡茶」", I18n.suggestions().contains("泡茶"))
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        var hidden = Settings()
        hidden.hiddenNames = ["泡茶", "冥想"]
        if let data = try? enc.encode(hidden), let back = try? dec.decode(Settings.self, from: data) {
            check("hiddenNames 存得返", back.hiddenNames == ["泡茶", "冥想"])
        } else {
            check("hiddenNames 存得返", false)
        }
        let legacy = #"{"theme":"dark","lang":"zh-Hant","badge":true,"notify":true,"sound":"alarm","soundVersion":2,"recentNames":[],"recentDurations":[]}"#
        if let data = legacy.data(using: .utf8), let back = try? dec.decode(Settings.self, from: data) {
            check("旧存档缺 hiddenNames 依然读得入", back.hiddenNames.isEmpty)
        } else {
            check("旧存档缺 hiddenNames 依然读得入", false)
        }

        print("\n=== 12. 建立即开始（走真实存档路径）===")
        // 这一段会真的动到存档，跑完马上还原
        let backupTimers = Store.shared.timers
        let backupSettings = Store.shared.settings
        let beforeCount = backupTimers.count
        let newId = Actions.create(
            name: "自測用", seconds: 45, accent: Engine.accents[0],
            isRepeating: false, notify: false, sound: "alarm"
        )
        let made = Store.shared.timers.first { $0.id == newId }
        check("真的进了牌堆", Store.shared.timers.count == beforeCount + 1)
        check("状态就是 running", made?.status == .running)
        check("endsAt 在未来", (made?.endsAt ?? 0) > Engine.nowMS())
        if let made {
            check("倒数看得见在跑", Engine.view(made, now: Engine.nowMS()).status == .running)
            check("剩余 = 45 秒", Engine.view(made, now: Engine.nowMS()).remaining > 44_000)
            // 画面第一帧就该是 00:45，而不是 00:46
            check("第一帧就是 00:45",
                  Engine.formatClock(Engine.view(made, now: Store.shared.now).remaining) == "00:45")
        } else {
            check("倒数看得见在跑", false)
            check("剩余 = 45 秒", false)
            check("第一帧就是 00:45", false)
        }
        // 还原使用者的存档
        Store.shared.setTimers(backupTimers)
        Store.shared.updateSettings { $0 = backupSettings }
        check("存档已还原", Store.shared.timers.count == beforeCount)

        print("\n=== 13. 新计时器不会多出一秒 ===")
        // 复现旧问题：「现在」每秒才更新一次，刚建立时画面读到的时间
        // 可能过期接近一秒，按旧算法会算出「时长 + 1 秒」
        let made900 = Engine.started(Engine.makeTimer(seconds: 900), now: now)
        let staleView = Engine.view(made900, now: now - 999)
        check("时间过期也不会多过时长", staleView.remaining <= 900_000)
        check("显示 15:00 而不是 15:01", Engine.formatClock(staleView.remaining) == "15:00")

        let exactView = Engine.view(made900, now: now)
        check("同一时间戳 → 恰好 15:00", Engine.formatClock(exactView.remaining) == "15:00")

        var tooLong = t
        tooLong.status = .paused
        tooLong.remaining = 999_999
        check("暂停中的旧存档也被上限修正",
              Engine.view(tooLong, now: now).remaining == 90_000)

        print("\n========================================")
        print("  通过 \(pass) / \(pass + fail)")
        if fail > 0 { print("  失败 \(fail) 项") }
        print("========================================\n")

        return true
    }
}
