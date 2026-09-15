import SwiftUI
import AppKit

// ============================================================================
//  UIRenderer — 开发用：把界面渲染成 PNG
//  以 `TimerDeck --render-ui --out=/path` 启动时执行，渲染完就结束。
//  正常使用（从 Finder 或菜单栏开启）完全不受影响。
// ============================================================================

enum UIRenderer {

    /// 回传 true 表示这是一次渲染执行，App 应该随即结束
    @MainActor
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--render-ui") else { return false }

        let outDir = CommandLine.arguments
            .first { $0.hasPrefix("--out=") }?
            .replacingOccurrences(of: "--out=", with: "") ?? "/tmp"

        try? FileManager.default.createDirectory(
            atPath: outDir, withIntermediateDirectories: true
        )

        let s = Store.shared.settings
        NSLog("[TimerDeck] 渲染前 theme=\(s.theme) lang=\(s.lang) isDark=\(Theme.resolve(s.theme, systemIsDark: false).isDark)")

        seedDemoTimers()

        render(DeckPanelView(previewFlatList: true), name: "01-panel-list", dir: outDir, height: 480)

        // 提示条现在与「N 進行中」共用顶部那一格，不再压住底部的「新增计时器」
        render(DeckPanelView(previewToast: I18n.t("toastSaved"), previewFlatList: true),
               name: "12-toast-saved", dir: outDir, height: 480)
        render(DeckPanelView(previewToast: I18n.t("toastDeletedNamed", ["name": "煮麵"]),
                             previewToastIcon: "trash.fill",
                             previewFlatList: true),
               name: "13-toast-deleted", dir: outDir, height: 480)

        // 让表单预览反映真实使用过的状态（有「最近用过」的名称与时长）
        Store.shared.updateSettings {
            $0.recentNames = ["沖咖啡", "泡茶", "小睡"]
            $0.recentDurations = [4500]
        }

        render(NewTimerView(theme: Theme(isDark: true), onDone: { _ in }),
               name: "02-panel-form", dir: outDir, height: 480)
        render(formFieldsPreview, name: "02b-form-fields", dir: outDir, width: 380)

        // 删掉两个内建建议之后：可见「還原建議名稱」的退路
        Store.shared.updateSettings { $0.hiddenNames = ["泡茶", "小睡"] }
        render(formFieldsPreview, name: "11-form-hidden-names", dir: outDir, width: 380)
        Store.shared.updateSettings {
            $0.hiddenNames = []
            $0.recentNames = []
            $0.recentDurations = []
        }
        render(DashboardView(), name: "03-dashboard", dir: outDir, width: 900, height: 620)
        render(CardShowcase(), name: "08-cards", dir: outDir, width: 640, height: 460)
        render(RowShowcase(), name: "09-rows", dir: outDir, width: 380, height: 400)
        render(ChipShowcase(), name: "10-chips", dir: outDir, width: 380, height: 330)
        render(MenuBarShowcase(), name: "14-menubar", dir: outDir, width: 430, height: 360)
        render(LogoShowcase(), name: "15-logo", dir: outDir, width: 430, height: 230)
        render(SettingsView(), name: "04-settings", dir: outDir, width: 460, height: 560)

        // 浅色主题
        Store.shared.updateSettings { $0.theme = "light" }
        render(DeckPanelView(previewFlatList: true), name: "05-panel-light", dir: outDir, height: 480)
        render(DashboardView(), name: "06-dashboard-light", dir: outDir, width: 900, height: 620)
        Store.shared.updateSettings { $0.theme = "dark" }

        // 英文
        Store.shared.updateSettings { $0.lang = "en" }
        render(DeckPanelView(previewFlatList: true), name: "07-panel-en", dir: outDir, height: 480)
        Store.shared.updateSettings { $0.lang = "zh-Hant" }

        // 收尾：清掉示范资料
        Store.shared.setTimers([])
        Store.shared.updateSettings {
            $0.recentNames = []; $0.recentDurations = []; $0.hiddenNames = []
        }

        return true
    }

    /// 造几个不同状态的计时器，方便检查列表与卡片的排版
    @MainActor
    private static func seedDemoTimers() {
        let now = Engine.nowMS()

        var a = Engine.makeTimer(name: "煮麵", seconds: 200, accent: Engine.accents[0])
        a.status = .running
        a.remaining = 200_000
        a.endsAt = now + 200_000

        var b = Engine.makeTimer(name: "小睡", seconds: 1800, accent: Engine.accents[1], isRepeating: true)
        b.status = .paused
        b.remaining = 18 * 60 * 1000

        var c = Engine.makeTimer(name: "泡茶", seconds: 300, accent: Engine.accents[2])
        c.status = .finished
        c.remaining = 0
        c.finishedAt = now - 120_000

        var d = Engine.makeTimer(name: "健身間歇", seconds: 60, accent: Engine.accents[3])
        d.status = .running
        d.remaining = 45_000
        d.endsAt = now + 45_000

        var e = Engine.makeTimer(name: "冥想", seconds: 600, accent: Engine.accents[4])
        e.status = .idle
        e.remaining = 600_000

        Store.shared.setTimers([a, b, c, d, e])
    }

    /// 表单主体的预览版本：补上面板底色
    /// （离屏渲染没有底色，透明处会变白，看起来像浅色主题）
    @MainActor
    private static var formFieldsPreview: some View {
        let theme = Theme(isDark: true)
        return NewTimerView(theme: theme, onDone: { _ in })
            .formFields
            .frame(width: 380)
            .background(theme.bg)
    }

    @MainActor
    private static func render<V: View>(
        _ view: V,
        name: String,
        dir: String,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        let content: AnyView
        if let w = width, let h = height {
            content = AnyView(view.frame(width: w, height: h))
        } else if let h = height {
            content = AnyView(view.frame(height: h))
        } else {
            content = AnyView(view)
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            NSLog("[TimerDeck] 渲染失败: \(name)")
            return
        }

        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try png.write(to: url)
            NSLog("[TimerDeck] 已输出 \(url.path)")
        } catch {
            NSLog("[TimerDeck] 写入失败 \(name): \(error)")
        }
    }
}

// ---------------------------------------------------------------------------
//  仪表板卡片的排版预览（离屏渲染无法展开 LazyVGrid，这里用 HStack 代替）
// ---------------------------------------------------------------------------

struct CardShowcase: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme.resolve(store.settings.theme, systemIsDark: scheme == .dark) }

    var body: some View {
        ZStack {
            theme.bgPage
            VStack(spacing: 14) {
                ForEach(Array(store.timers.prefix(4)).chunked(2), id: \.first?.id) { pair in
                    HStack(spacing: 14) {
                        ForEach(pair) { t in
                            TimerCardView(
                                timer: t, now: store.now, theme: theme,
                                onToggle: {}, onReset: {}, onDuplicate: {},
                                onRename: {}, onDelete: {}
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// ---------------------------------------------------------------------------
//  名称建议名片的排版预览（hover 状态在离屏渲染里不会触发，这里强制打开）
// ---------------------------------------------------------------------------

struct ChipShowcase: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme.resolve(store.settings.theme, systemIsDark: scheme == .dark) }

    var body: some View {
        ZStack {
            theme.bg
            VStack(alignment: .leading, spacing: 14) {
                Text("Hover 時，尾端浮現刪除鍵")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textMute)

                FlowRow(spacing: 6) {
                    ForEach(["泡茶", "小睡", "沖咖啡", "冥想"], id: \.self) { s in
                        ChipView(text: s, theme: theme, onRemove: {}, forceHover: true, action: {})
                    }
                }

                Text("已選中（藍底藍字）／最近用過（灰字＋小鬧鐘）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textMute)

                FlowRow(spacing: 6) {
                    ChipView(text: "煮麵", theme: theme, selected: true, onRemove: {}, forceHover: true, action: {})
                    ChipView(text: "健身間歇", theme: theme, recent: true, onRemove: {}, forceHover: true, action: {})
                }

                Text("無刪除鍵（時長模板的樣子）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textMute)

                FlowRow(spacing: 6) {
                    ForEach(["1 分鐘", "15 分鐘"], id: \.self) { s in
                        ChipView(text: s, theme: theme, action: {})
                    }
                }

                // 用户回报的情况：同一组里面「已选中」和「最近用过」并存，
                // 现在应该只见到一个蓝字
                Text("同一组：已選中 + 最近用過（只有一個藍字）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textMute)

                FlowRow(spacing: 6) {
                    ChipView(text: "1 分鐘", theme: theme, action: {})
                    ChipView(text: "15 分鐘", theme: theme, selected: true, action: {})
                    ChipView(text: "30 分鐘", theme: theme, action: {})
                    ChipView(text: "1 小時 15 分鐘", theme: theme, recent: true, action: {})
                }
            }
            .padding(16)
        }
    }
}

// ---------------------------------------------------------------------------
//  菜单栏外观预览（离屏渲染画不出真正的菜单栏，这里模拟一条右下角）
// ---------------------------------------------------------------------------

struct MenuBarShowcase: View {
    private static let states: [(label: String, text: String?)] = [
        ("一個計時器在倒數 → 直接顯示剩餘時間", "12:34"),
        ("超過一小時", "1:15:00"),
        ("三個計時器在跑 → 顯示數量", "3"),
        ("沒有計時器在跑 → 只有圖示", nil),
    ]

    var body: some View {
        ZStack {
            Color(hex: "1E1E1E")
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Self.states, id: \.label) { state in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "9A9A9A"))

                        HStack(spacing: 13) {
                            Spacer(minLength: 0)
                            MenuBarLabelContent(text: state.text)
                                .foregroundStyle(.white)
                            Image(systemName: "wifi")
                            Image(systemName: "battery.100")
                            Text("23:26")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "8A8A8A"))
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Color(hex: "2A2C31"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(18)
        }
    }
}

// ---------------------------------------------------------------------------
//  品牌记号预览（界面内用的小 logo，与实际 app 图示同一套比例）
// ---------------------------------------------------------------------------

struct LogoShowcase: View {
    var body: some View {
        ZStack {
            Color(hex: "1E1E1E")
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 20) {
                    ForEach([28, 40, 56, 88], id: \.self) { s in
                        VStack(spacing: 8) {
                            LogoMark(size: CGFloat(s))
                            Text("\(s)px")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "8A8A8A"))
                        }
                    }
                }
                Divider().overlay(Color(hex: "333333"))
                HStack(spacing: 11) {
                    LogoMark(size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timer Deck")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("選單列倒數計時器")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "8A8A8A"))
                    }
                }
            }
            .padding(20)
        }
    }
}

// ---------------------------------------------------------------------------
//  面板列表行的排版预览（同样避开 ScrollView）
// ---------------------------------------------------------------------------

struct RowShowcase: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme.resolve(store.settings.theme, systemIsDark: scheme == .dark) }

    var body: some View {
        ZStack {
            theme.bg
            VStack(spacing: 6) {
                ForEach(store.timers) { t in
                    TimerRowView(
                        timer: t, now: store.now, theme: theme,
                        onToggle: {}, onReset: {}, onDuplicate: {},
                        onRename: {}, onDelete: {}
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
