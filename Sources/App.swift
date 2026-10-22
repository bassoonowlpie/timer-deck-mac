import SwiftUI
import AppKit

// ============================================================================
//  Timer Deck — App 进入点
//  常驻菜单栏（不占 Dock），对应浏览器版的 background + action popup
// ============================================================================

@main
struct TimerDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = Store.shared

    var body: some Scene {
        MenuBarExtra {
            DeckPanelView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window(I18n.t("dashTitle"), id: "dashboard") {
            DashboardView()
        }
        .windowResizability(.contentMinSize)

        Window(I18n.t("optionsTitle"), id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

// ---------------------------------------------------------------------------

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 开发用：逻辑自测
        if SelfTest.runIfRequested() {
            NSApp.terminate(nil)
            return
        }

        // 开发用：把界面渲染成 PNG 后直接结束
        if UIRenderer.runIfRequested() {
            NSApp.terminate(nil)
            return
        }

        // 开发用：验证菜单栏右键菜单（合成一次右键事件）
        if CommandLine.arguments.contains("--probe-menu") {
            Store.shared.startTicking()
            NSApp.setActivationPolicy(.accessory)
            StatusMenuController.shared.install()
            StatusMenuController.shared.runProbe()
            return
        }

        Store.shared.startTicking()

        // 菜单栏图示的右键菜单（退出 / 设定 / 仪表板）
        StatusMenuController.shared.install()

        if Store.shared.settings.notify {
            Notifier.shared.requestPermission()
        }

        // 纯菜单栏 app，不要 Dock 图示
        NSApp.setActivationPolicy(.accessory)

        // 首次启动给个提示，免得用户找不到。
        // 提示状态写进 settings（只提示一次）—— 之前用内存变量，每次启动都会重弹。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard !Store.shared.settings.hintShown else { return }
            Store.shared.updateSettings { $0.hintShown = true }
            Notifier.shared.fire(
                title: I18n.t("appName"),
                body: I18n.t("hintKeepRunning")
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Store.shared.save()
        Store.shared.stopTicking()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// ---------------------------------------------------------------------------
//  菜单栏图示
//  只有一个计时器在跑时 → 直接显示剩余时间；多个 → 显示数量
//  （对应浏览器版的 action badge，但多了「看得到倒数」这一层）
// ---------------------------------------------------------------------------

struct MenuBarLabel: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.openWindow) private var openWindow

    /// 关了「選單列顯示」就什么都不显示，只留图示
    private var segments: [Engine.MenuBarSegment] {
        guard store.settings.badge else { return [] }
        return Engine.menuBarSegments(store.timers, now: store.now)
    }

    var body: some View {
        MenuBarLabelContent(segments: segments)
            .accessibilityLabel("Timer Deck")
            .onAppear {
                // 让菜单栏的右键菜单也能开视窗
                StatusMenuController.openWindow = openWindow
            }
    }
}

/// 图示 + 文字。抽出来是为了能离屏渲染成预览图。
struct MenuBarLabelContent: View {
    var segments: [Engine.MenuBarSegment] = []

    /// 所有计时器拼成「单一」文字 —— 真实菜单栏对 HStack 里多个 Text 的渲染会掉字，
    /// 只出第一个；合成一个 AttributedString 才稳定，还能各自保留颜色。
    /// 每个计时器前面都加上名称（如「煮麵 12:34 · 泡茶 45:12」）。
    private var label: AttributedString {
        var out = AttributedString()
        for (i, seg) in segments.enumerated() {
            if i > 0 { out += AttributedString(" · ") }
            var nm = AttributedString(seg.name + " ")
            nm.foregroundColor = Color(hex: seg.accentHex)
            out += nm
            var tm = AttributedString(seg.text)
            tm.foregroundColor = Color(hex: seg.accentHex)
            out += tm
        }
        return out
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "timer")
            if !segments.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}
