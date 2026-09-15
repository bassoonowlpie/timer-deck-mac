import SwiftUI
import AppKit

// ============================================================================
//  Timer Deck — 菜单栏图示的「右键菜单」
//
//  SwiftUI 的 MenuBarExtra 只处理左键，官方没有提供右键 API。
//  这里用「本地事件监听」拦截落在菜单栏图示上的右键，再弹出真正的 NSMenu。
//  左键完全不受影响，仍然是原来的面板。
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
    /// 装上右键监听。只需要装一次。
    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .rightMouseUp]) { [weak self] event in
            guard let self, self.isStatusBarWindow(event.window) else { return event }

            if event.type == .rightMouseDown {
                self.showMenu(for: event)
            }
            // 两种情况都吃掉，MenuBarExtra 的面板就不会被右键带着一起弹出来
            return nil
        }
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
}
