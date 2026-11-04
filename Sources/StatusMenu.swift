import SwiftUI
import AppKit
import Combine

// ============================================================================
//  Timer Deck — 菜单栏图示的「右键菜单」与「中键重设」
//
//  SwiftUI 的 MenuBarExtra 只处理左键，官方没有提供右键 / 中键 API。
//  这里用 NSEvent 监听拦截额外按键：
//    · 右键（只限选单列图示）→ 弹出真正的 NSMenu；面板内右键交返 SwiftUI contextMenu
//    · 中键（鼠标滚轮按下去）→ **本 app 任何一个视窗**都受理：
//        面板／仪表板入面指住边个计时器就重设边个，
//        撳选单列图示就重设最快到期嗰个（冇进行中都照重设）
//
//  ⚠️ 早期版本净系认 NSStatusBarWindow，实测用户几乎全部中键都撳喺面板入面
//  （诊断日志：win#=571698、y≈1120，唔系图示视窗 win#=6、y≈1424），
//  所以改坐标范围点调都系「撳咗冇反应」。而家靠 hover 目标 + 全视窗监听解决。
//  左键完全不受影响，仍然是原来的面板。整套做法只收本 app 自己的事件，
//  不需要「辅助使用」权限，也不用改任何系统设定。
// ============================================================================

/// 选单列上的短暂提示（约 2 秒）。按中键之后一定要有可见回应，
/// 免得用户以为「按了没反应」。
final class MenuBarFlash: ObservableObject {
    static let shared = MenuBarFlash()

    @Published var text: String?
    private var pending: DispatchWorkItem?

    func show(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending?.cancel()
            self.text = message
            let clear = DispatchWorkItem { [weak self] in self?.text = nil }
            self.pending = clear
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: clear)
        }
    }
}

final class StatusMenuController: NSObject {

    static let shared = StatusMenuController()

    /// SwiftUI 的开视窗动作。在 view tree 里抓出来存着，
    /// 好让 NSMenu 也能开仪表板 / 设定视窗。
    static var openWindow: OpenWindowAction?

    private var monitor: Any?
    private var globalMonitor: Any?
    private weak var statusWindow: NSWindow?
    private var lastResetAt: Date = .distantPast

    // 开发用（--probe-menu）
    private var probeMode = false
    private var probeLog: [String] = []

    // ------------------------------------------------------------ 安装 --
    /// 装上右键 / 中键监听。只需要装一次。
    func install() {
        guard monitor == nil else { return }

        // ── 本 app 自己的事件 ──────────────────────────────────────────
        // 关键：中键**不再**限制喺 NSStatusBarWindow。面板、仪表板、设定视窗
        // 收到嘅 .otherMouseDown 一律受理，再用 hover 目标决定重设边个。
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
        ) { [weak self] event in
            guard let self else { return event }

            // 右键：净系选单列图示弹菜单。面板入面要留返畀 SwiftUI 嘅 contextMenu。
            if event.type == .rightMouseDown || event.type == .rightMouseUp {
                guard self.isStatusBarWindow(event.window) else { return event }
                if event.type == .rightMouseDown { self.showMenu(for: event) }
                return nil
            }

            // 中键 / 其他额外按键 → 重设。
            // 按事件型别判断而唔靠 buttonNumber：macOS 实机中键系 .otherMouseDown，
            // 但数字会因鼠标驱动而异（合成事件甚至全部报 0），用型别最稳。
            if event.type == .otherMouseDown { self.resetFromMiddleClick() }
            return nil
        }

        // ── 兜底：选单列图示有时属于系统视窗，事件唔会派发畀本 app ──────
        // 全域监听只收「发去其他 process」嘅鼠标事件，唔需要任何权限；
        // 呢条路唔会有 hover 目标，所以会重设「最快到期／第一个」。
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.otherMouseDown]
        ) { [weak self] _ in
            guard let self, self.isMouseOverStatusBarIcon() else { return }
            DispatchQueue.main.async { self.resetFromMiddleClick() }
        }
    }

    /// 全域监听收到事件时，用鼠标坐标判断是否按在选单列图示一带。
    /// 只要求 y 落在菜单栏条带（屏幕顶 34pt）；x 由图示范围向左放宽 160pt ——
    /// 图示会随「名称 + 时间」文字变宽，实测亦有用户按在图示左 28pt 嘅位置。
    /// NSWindow.frame 与 NSEvent.mouseLocation 都用「左下为原点」的屏幕坐标。
    private func isMouseOverStatusBarIcon() -> Bool {
        let p = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main else {
            return false
        }
        guard p.y >= screen.frame.maxY - 34 else { return false }

        guard let win = NSApp.windows.first(where: { isStatusBarWindow($0) }) else { return true }
        return p.x >= win.frame.minX - 160 && p.x <= win.frame.maxX + 40
    }

    /// 中键重设：**指住边个就重设边个**。
    /// 游标停喺清单某一列（面板／仪表板）就用嗰个 ID；否则退回最快到期／第一个。
    /// 效果跟面板里的「重设」按钮一致：停低、时长度归回初始值、不自动倒数。
    /// 无论成功与否都给一个可见提示，让用户知道按键有被收到。
    private func resetFromMiddleClick() {
        // 本地与全域监听可能同时看到同一次点击，0.4 秒内只处理一次
        let now = Date()
        guard now.timeIntervalSince(lastResetAt) > 0.4 else { return }

        let store = Store.shared
        let hoveredID = MiddleClickTracker.shared.hoveredTimerID
        guard let id = Engine.resetTargetID(store.timers, hoveredID: hoveredID, now: store.now) else {
            MenuBarFlash.shared.show(I18n.t("flashNoTimers"))
            return
        }

        lastResetAt = now
        let name = store.timers.first(where: { $0.id == id })?.name ?? ""
        Actions.reset(id)
        let message = "✓ " + I18n.t("toastReset") + " · " + String(name.prefix(10))
        MenuBarFlash.shared.show(message)
        // 面板／仪表板可能开住，选单列提示会睇唔到 —— 同时广播畀面板显示 toast
        NotificationCenter.default.post(name: .timerDeckMiddleClickReset, object: message)
        if probeMode { probeLog.append("✅ 中键重设 → \(id)") }
    }

    /// 判断事件是不是落在本 app 的菜单栏图示上
    private func isStatusBarWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        if let known = statusWindow, known === window { return true }

        // 主要判断：视窗类别名称
        if String(describing: type(of: window)).contains("StatusBar") {
            statusWindow = window
            return true
        }
        // 退路：视窗里找得到 NSStatusBarButton 就当它是菜单栏图示
        if let content = window.contentView, Self.containsStatusButton(content) {
            statusWindow = window
            return true
        }
        return false
    }

    private static func containsStatusButton(_ view: NSView) -> Bool {
        if view is NSStatusBarButton { return true }
        for sub in view.subviews where containsStatusButton(sub) { return true }
        return false
    }

    // ------------------------------------------------------------ 菜单 --
    private func showMenu(for event: NSEvent) {
        let menu = buildMenu()
        NSApp.activate(ignoringOtherApps: true)

        let anchor: NSPoint
        if let w = event.window {
            anchor = w.convertPoint(toScreen: event.locationInWindow)
        } else {
            anchor = NSEvent.mouseLocation
        }

        if probeMode {
            probeLog.append("✅ 右键被拦截，菜单已建立（项目数 = \(menu.items.count)）")
            // 别让自动化测试卡在 modal 里
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { menu.cancelTracking() }
        }

        menu.popUp(positioning: nil, at: NSPoint(x: anchor.x - 6, y: anchor.y - 6), in: nil)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(makeItem(I18n.t("openDashboard"), #selector(openDashboard), "square.grid.2x2"))
        menu.addItem(makeItem(I18n.t("settings"), #selector(openSettings), "slider.horizontal.3"))
        menu.addItem(.separator())

        let quit = makeItem(I18n.t("quit"), #selector(quitApp), "power")
        quit.keyEquivalent = "q"
        menu.addItem(quit)

        return menu
    }

    private func makeItem(_ title: String, _ action: Selector, _ symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            item.image = image
        }
        return item
    }

    // ------------------------------------------------------------ 动作 --
    @objc private func openDashboard() {
        Self.openWindow?(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        Self.openWindow?(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        Store.shared.save()
        NSApp.terminate(nil)
    }

    // ------------------------------------------------------- 开发用自测 --
    /// `--probe-menu`：投递一个合成右键事件，验证「监听 → 拦截 → 弹菜单」整条路走得通，
    /// 结果写到 ~/Library/Application Support/TimerDeck/probe.txt 后结束。
    func runProbe() {
        probeMode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }

            let names = NSApp.windows.map { String(describing: type(of: $0)) }
            self.probeLog.append("NSApp.windows = [\(names.joined(separator: ", "))]")
            for w in NSApp.windows {
                self.probeLog.append("  window \(String(describing: type(of: w))) frame=\(w.frame)")
            }
            self.probeLog.append("  屏幕 frame=\(NSScreen.main?.frame ?? .zero)")

            let win = NSApp.windows.first { self.isStatusBarWindow($0) }
            self.probeLog.append("找到菜单栏图示视窗 = \(win.map { String(describing: type(of: $0)) } ?? "❌ 找不到")")

            guard let win else {
                self.finishProbe(success: false)
                return
            }

            let local = NSPoint(x: win.frame.midX - win.frame.origin.x, y: win.frame.height / 2)
            guard let event = NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: local,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: win.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            ) else {
                self.probeLog.append("❌ 无法建立合成事件")
                self.finishProbe(success: false)
                return
            }

            self.probeLog.append("→ 投递合成右键事件 (windowNumber \(win.windowNumber))")
            NSApp.postEvent(event, atStart: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                self.finishProbe(success: self.probeLog.contains { $0.hasPrefix("✅") })
            }
        }
    }

    /// `--probe-row`：模拟用户喺**面板入面**对住某一列撳中键。
    /// 早期嘅 probe 净系测选单列图示视窗，所以真实场景坏咗都测唔出。
    /// 呢度用一个普通 NSWindow（非 status bar）+ hover 目标，
    /// 验证「指边个重设边个」同「本 app 任何视窗都受理」两件事。
    func runRowProbe() {
        probeMode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }

            let now = Engine.nowMS()
            var fastest = Engine.makeTimer(name: "最快", seconds: 30)
            fastest.status = .running
            fastest.remaining = 30_000
            fastest.endsAt = now + 30_000
            var slower = Engine.makeTimer(name: "指住呢个", seconds: 300)
            slower.status = .running
            slower.remaining = 300_000
            slower.endsAt = now + 300_000
            Store.shared.setTimers([fastest, slower])
            MiddleClickTracker.shared.hoveredTimerID = slower.id
            self.probeLog.append("放入 2 个进行中计时器，hover 目标 = 较慢嗰个（\(slower.name)）")

            // 一个普通视窗，刻意唔系 NSStatusBarWindow
            let win = NSWindow(
                contentRect: NSRect(x: 300, y: 300, width: 380, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            win.title = "探针面板"
            win.makeKeyAndOrderFront(nil)
            self.probeLog.append("建立普通面板视窗 windowNumber \(win.windowNumber)（非 status bar）")

            guard let event = NSEvent.mouseEvent(
                with: .otherMouseDown,
                location: NSPoint(x: 190, y: 240),
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: win.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            ) else {
                self.probeLog.append("❌ 无法建立合成中键事件")
                self.finishProbe(success: false)
                return
            }
            self.probeLog.append("→ 投递合成中键事件到面板视窗")
            NSApp.postEvent(event, atStart: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let slow = Store.shared.timers.first { $0.id == slower.id }
                let fast = Store.shared.timers.first { $0.id == fastest.id }
                let slowReset = slow?.status == .idle && slow?.remaining == 300_000
                let fastUntouched = fast?.status == .running
                self.probeLog.append(slowReset
                    ? "✅ 面板中键重设咗「指住呢个」（idle／05:00）"
                    : "❌ 面板中键冇重设 hover 目标（status=\(String(describing: slow?.status))）")
                self.probeLog.append(fastUntouched
                    ? "✅ 最快到期嗰个无受影响"
                    : "❌ 错误噉重设咗最快到期嗰个")
                self.finishProbe(success: slowReset && fastUntouched)
            }
        }
    }

    private func finishProbe(success: Bool) {
        probeLog.append(success ? "===== 通过 =====" : "===== 失败 =====")
        let text = probeLog.joined(separator: "\n")
        let path = Store.dataDirPath + "/probe.txt"
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
        NSLog("[TimerDeck] probe:\n\(text)")
        NSApp.terminate(nil)
    }

    /// `--probe-middle`：合成一个落在菜单栏图示上的中键事件，
    /// 验证「监听 → 拦截 → 重设」整条路走得通。资料写在隔离目录，唔掂真实存档。
    func runMiddleProbe() {
        probeMode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }

            let names = NSApp.windows.map { String(describing: type(of: $0)) }
            self.probeLog.append("NSApp.windows = [\(names.joined(separator: ", "))]")
            for w in NSApp.windows {
                self.probeLog.append("  window \(String(describing: type(of: w))) frame=\(w.frame)")
            }
            self.probeLog.append("  屏幕 frame=\(NSScreen.main?.frame ?? .zero)")

            guard let win = NSApp.windows.first(where: { self.isStatusBarWindow($0) }) else {
                self.probeLog.append("❌ 找不到菜单栏图示视窗")
                self.finishProbe(success: false)
                return
            }
            self.probeLog.append("找到菜单栏图示视窗 = \(String(describing: type(of: win)))")

            let now = Engine.nowMS()
            var timer = Engine.makeTimer(name: "探针", seconds: 300)
            timer.status = .running
            timer.remaining = 300_000
            timer.endsAt = now + 300_000
            Store.shared.setTimers([timer])
            self.probeLog.append("放入 1 个进行中计时器（05:00）")

            let local = NSPoint(x: win.frame.width / 2, y: win.frame.height / 2)
            guard let event = NSEvent.mouseEvent(
                with: .otherMouseDown,
                location: local,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: win.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            ) else {
                self.probeLog.append("❌ 无法建立合成中键事件")
                self.finishProbe(success: false)
                return
            }
            self.probeLog.append("→ 投递合成中键事件 (windowNumber \(win.windowNumber))")
            NSApp.postEvent(event, atStart: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let after = Store.shared.timers.first
                let status = after.map { String(describing: $0.status) } ?? "无"
                let remaining = after?.remaining ?? -1
                let ok = status == "idle" && remaining == 300_000
                self.probeLog.append(ok
                    ? "✅ 中键已触发重设（status=idle, remaining=05:00）"
                    : "❌ 中键未生效（status=\(status), remaining=\(remaining))")
                self.finishProbe(success: ok)
            }
        }
    }
}
