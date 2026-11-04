import SwiftUI
import AppKit

// ============================================================================
//  Timer Deck — 菜单栏图示的「右键菜单」与「中键重设」
//
//  SwiftUI 的 MenuBarExtra 只处理左键，官方没有提供右键 / 中键 API。
//  这里用「本地事件监听」拦截落在菜单栏图示上的右键与中键：
//    · 右键 → 弹出真正的 NSMenu
//    · 中键（鼠标滚轮按下去，buttonNumber == 2）→ 重设最快到期的计时器
//  左键完全不受影响，仍然是原来的面板。整套做法只收本 app 自己的事件，
//  不需要「辅助使用」权限，也不用改任何系统设定。
// ============================================================================

final class StatusMenuController: NSObject {

    static let shared = StatusMenuController()

    /// SwiftUI 的开视窗动作。在 view tree 里抓出来存着，
    /// 好让 NSMenu 也能开仪表板 / 设定视窗。
    static var openWindow: OpenWindowAction?

    private var monitor: Any?
    private weak var statusWindow: NSWindow?

    // 开发用（--probe-menu）
    private var probeMode = false
    private var probeLog: [String] = []

    // ------------------------------------------------------------ 安装 --
    /// 装上右键 / 中键监听。只需要装一次。
    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
        ) { [weak self] event in
            guard let self, self.isStatusBarWindow(event.window) else { return event }

            // 右键 → 菜单（down 弹，up 一起吃掉，免得面板被带出来）
            if event.type == .rightMouseDown { self.showMenu(for: event) }
            if event.type == .rightMouseDown || event.type == .rightMouseUp { return nil }

            // 中键 / 其他额外按键 → 重设。
            // 按事件型别判断而唔靠 buttonNumber：macOS 实机中键系 .otherMouseDown，
            // 但数字会因鼠标驱动而异（合成事件甚至全部报 0），用型别最稳。
            // 侧键撳中呢个咁细嘅图示几乎唔会发生，一齐当重设亦无妨。
            if event.type == .otherMouseDown { self.resetFromMenuBar() }
            return nil
        }
    }

    /// 重设选单列上排最前（最快到期）的进行中计时器。
    /// 效果跟面板里的「重设」按钮一致：停低、时长度归回初始值、不自动倒数。
    private func resetFromMenuBar() {
        let store = Store.shared
        guard let id = Engine.menuBarResetTargetID(store.timers, now: store.now) else { return }
        Actions.reset(id)
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
