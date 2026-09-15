import SwiftUI

// ============================================================================
//  Timer Deck — 菜单栏面板
//  对应浏览器版的 popup：列表视图 ＋ 新增表单
// ============================================================================

enum PanelMode {
    case list
    case form
}

struct DeckPanelView: View {
    /// 开发预览用：离屏渲染没有互动，这里直接让提示条显示出来
    var previewToast: String? = nil
    var previewToastIcon: String = "checkmark.circle.fill"
    /// 开发预览用：离屏渲染的 ScrollView 撑不开，预览时把列表摊平
    var previewFlatList: Bool = false

    @ObservedObject private var store = Store.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openWindow) private var openWindow

    @LocalState private var mode: PanelMode = .list
    @LocalState private var renameID: String?
    @LocalState private var renameText = ""
    @LocalState private var toast: String?
    @LocalState private var toastIcon = "checkmark.circle.fill"
    @LocalState private var lastRemoved: [Actions.Removed] = []
    @LocalState private var toastTask: Task<Void, Never>?

    private var theme: Theme { Theme.resolve(store.settings.theme, systemIsDark: scheme == .dark) }

    var body: some View {
        ZStack {
            theme.bg
            VStack(spacing: 0) {
                switch mode {
                case .list:
                    listView
                case .form:
                    NewTimerView(theme: theme, onDone: { saved in
                        withAnimation(.easeOut(duration: 0.18)) { mode = .list }
                        if saved { showToast(I18n.t("toastSaved")) }
                    })
                }
            }

            // 重新命名用内嵌浮层，不用 sheet（菜单栏窗口对 sheet 支援不稳）
            if renameID != nil {
                Color.black.opacity(0.35)
                    .onTapGesture { renameID = nil }
                renameCard
            }
        }
        .frame(width: 380, height: 480)
        .onAppear {
            store.refreshNow()
            // 让菜单栏的右键菜单也能开视窗
            StatusMenuController.openWindow = openWindow
            if let t = previewToast {
                toast = t
                toastIcon = previewToastIcon
            }
        }
    }

    // ------------------------------------------------------------- 列表 --
    private var listView: some View {
        VStack(spacing: 0) {
            header
            topBar
            Divider().overlay(theme.divider)
            timerList
            Divider().overlay(theme.divider)
            footer
        }
    }

    /// 顶部那一条：平时是「N 進行中」的状态胶囊，有提示时就换成提示条。
    /// 两者共用同一个位置 —— 所以提示永远不会盖住任何按钮。
    @ViewBuilder
    private var topBar: some View {
        if let text = toast {
            toastBar(text)
        } else {
            strip
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            LogoMark(size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("Timer Deck")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMute)
            }

            Spacer()

            IconBtn(systemName: "slider.horizontal.3", theme: theme, help: I18n.t("settings")) {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var statusLine: String {
        let s = Actions.summary(now: store.now)
        if s.total == 0 { return I18n.t("statusEmpty") }
        if s.running > 0 && s.paused > 0 {
            return I18n.t("statusRunningPaused", ["r": "\(s.running)", "p": "\(s.paused)"])
        }
        if s.running > 0 { return I18n.t("statusRunningOnly", ["r": "\(s.running)"]) }
        if s.paused > 0 { return I18n.t("statusPausedOnly", ["p": "\(s.paused)"]) }
        return I18n.t("statusAllStopped")
    }

    /// 状态条只显示「进行中」——其他数字对这个面板没有帮助
    private var strip: some View {
        let s = Actions.summary(now: store.now)
        return Group {
            if s.running > 0 {
                HStack(spacing: 6) {
                    PillView(text: I18n.t("pillRunning", ["n": "\(s.running)"]), tone: .run, theme: theme)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 9)
            }
        }
    }

    @ViewBuilder
    private var timerList: some View {
        if store.timers.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(theme.textFaint)
                Text(I18n.t("emptyTitle"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textDim)
                Text(I18n.t("emptyText"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if previewFlatList {
            // 离屏渲染的 ScrollView 撑不开，预览时直接摊平
            timerRows
        } else {
            ScrollView { timerRows }
                .frame(maxHeight: .infinity)
        }
    }

    private var timerRows: some View {
        VStack(spacing: 6) {
            ForEach(store.timers) { timer in
                TimerRowView(
                    timer: timer,
                    now: store.now,
                    theme: theme,
                    onToggle: { Actions.toggle(timer.id) },
                    onReset: {
                        Actions.reset(timer.id)
                        showToast(I18n.t("toastReset"))
                    },
                    onDuplicate: {
                        Actions.duplicate(timer.id)
                        showToast(I18n.t("toastDuplicated"))
                    },
                    onRename: {
                        renameText = timer.name
                        renameID = timer.id
                    },
                    onDelete: { delete(timer) }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            DeckButton(
                title: I18n.t("newTimer"),
                theme: theme,
                systemImage: "plus",
                primary: true,
                fullWidth: true
            ) {
                withAnimation(.easeOut(duration: 0.18)) { mode = .form }
            }

            let finished = Actions.finishedIds(now: store.now)
            if !finished.isEmpty {
                IconBtn(systemName: "checkmark.circle", theme: theme, help: I18n.t("clearFinished")) {
                    clearFinished(finished)
                }
            }

            IconBtn(systemName: "arrow.up.right.square", theme: theme, help: I18n.t("openDashboard")) {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // ------------------------------------------------------- 重新命名 --
    private var renameCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(I18n.t("rename"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text)

            TextField(I18n.t("namePlaceholder"), text: $renameText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(theme.surface2, in: RoundedRectangle(cornerRadius: Metrics.rSM))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rSM)
                        .stroke(theme.border, lineWidth: 1)
                )
                .onSubmit { commitRename() }

            HStack {
                Spacer()
                DeckButton(title: I18n.t("cancel"), theme: theme, primary: false) { renameID = nil }
                DeckButton(title: I18n.t("save"), theme: theme, primary: true) { commitRename() }
            }
        }
        .padding(18)
        .frame(width: 300)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Metrics.r2XL))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.r2XL)
                .stroke(theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
    }

    private func commitRename() {
        if let id = renameID {
            Actions.rename(id, to: renameText)
            showToast(I18n.t("toastRenamed"))
        }
        renameID = nil
    }

    // ---------------------------------------------------------- 操作 --
    private func delete(_ timer: TimerItem) {
        if let removed = Actions.remove(timer.id) {
            lastRemoved = [removed]
            let label = timer.name.isEmpty ? I18n.t("toastDeleted") : I18n.t("toastDeletedNamed", ["name": timer.name])
            showToast(label, icon: "trash.fill")
        }
    }

    private func clearFinished(_ ids: [String]) {
        let removed = Actions.removeMany(ids)
        guard !removed.isEmpty else { return }
        lastRemoved = removed
        showToast(I18n.t("toastClearedFinished", ["n": "\(removed.count)"]), icon: "trash.fill")
    }

    // ---------------------------------------------------------- Toast --
    private func showToast(_ text: String, icon: String = "checkmark.circle.fill") {
        toastTask?.cancel()
        toastIcon = icon
        withAnimation(.easeOut(duration: 0.15)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    toast = nil
                    lastRemoved = []
                }
            }
        }
    }

    /// 顶部那一条提示。宽度与状态胶囊对齐，不会压到任何按钮。
    private func toastBar(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: toastIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(toastIcon == "trash.fill" ? theme.coral : theme.ok)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            Spacer(minLength: 8)

            if !lastRemoved.isEmpty {
                Button(I18n.t("undo")) {
                    Actions.restoreMany(lastRemoved)
                    lastRemoved = []
                    toastTask?.cancel()
                    withAnimation { toast = nil }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(theme.surface2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// ============================================================================
//  单行计时器
// ============================================================================

struct TimerRowView: View {
    let timer: TimerItem
    let now: Double
    let theme: Theme
    var onToggle: () -> Void
    var onReset: () -> Void
    var onDuplicate: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void

    @LocalState private var hovering = false

    private var v: TimerView { Engine.view(timer, now: now) }
    private var tone: RingTone { Engine.tone(for: v) }

    private var subtitle: String {
        switch v.status {
        case .running:
            if v.remaining <= Engine.soonMS { return I18n.t("subAlmost") }
            if let endsAt = v.endsAt { return I18n.t("subEnds", ["time": Engine.clockTime(endsAt, lang: I18n.current)]) }
            return I18n.t("subNotStarted")
        case .finished:
            let at = v.finishedAt ?? now
            return I18n.t("subEnded", ["time": Engine.clockTime(at, lang: I18n.current)])
        case .paused:
            return I18n.t("subPaused")
        case .idle:
            return I18n.t("subNotStarted")
        }
    }

    private var subtitleColor: Color {
        if v.status == .running && v.remaining <= Engine.soonMS { return theme.warn }
        if v.status == .finished { return theme.ok }
        return theme.textMute
    }

    private var rowTint: Color {
        guard v.status != .idle else { return .clear }
        return Color(hex: timer.accent).opacity(theme.isDark ? 0.10 : 0.07)
    }

    private var toggleIcon: String {
        v.status == .running ? "pause.fill" : "play.fill"
    }

    /// 常驻在行尾的操作区：暂停/继续、重新命名、重设、複製、刪除
    /// （以前要按「···」才展开，现在直接摊开，不必多按一下）
    private var actionGroup: some View {
        HStack(spacing: 1) {
            IconBtn(
                systemName: toggleIcon,
                theme: theme,
                help: v.status == .running ? I18n.t("actionPause") : I18n.t("actionResume"),
                size: 25
            ) { onToggle() }

            IconBtn(systemName: "pencil", theme: theme, help: I18n.t("rename"), size: 25) { onRename() }
            IconBtn(systemName: "arrow.counterclockwise", theme: theme, help: I18n.t("reset"), size: 25) { onReset() }
            IconBtn(systemName: "doc.on.doc", theme: theme, help: I18n.t("duplicate"), size: 25) { onDuplicate() }
            IconBtn(systemName: "trash", theme: theme, help: I18n.t("delete"), danger: true, size: 25) { onDelete() }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Button(action: onToggle) {
                    RingView(tone: tone, progress: v.progress, accentHex: timer.accent, theme: theme, size: 38)
                }
                .buttonStyle(.plain)
                .help(v.status == .running ? I18n.t("actionPause") : I18n.t("actionResume"))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(timer.name.isEmpty ? I18n.t("defaultName") : timer.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if timer.isRepeating {
                            Image(systemName: "repeat")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textFaint)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(Engine.formatClock(v.remaining))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(v.status == .finished ? theme.textMute : theme.text)

                actionGroup
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLG)
                .fill(rowTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.rLG)
                .stroke(v.status == .finished ? theme.ok.opacity(0.35) : (hovering ? theme.border : .clear), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLG)
                .fill(hovering ? theme.surfaceHover.opacity(theme.isDark ? 0.6 : 1) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(I18n.t("rename"), action: onRename)
            Button(I18n.t("reset"), action: onReset)
            Button(I18n.t("duplicate"), action: onDuplicate)
            Divider()
            Button(I18n.t("delete"), role: .destructive, action: onDelete)
        }
    }
}

// ============================================================================
//  App 图示 / 品牌记号
//  几何与 make_app_icon.py 完全一致（圆角方块 / 表圈 0.72 / 按把 0.30×0.066），
//  这样界面里的小 logo 与实际 app 图示是同一套比例。
// ============================================================================

struct LogoMark: View {
    var size: CGFloat = 28

    // 与 make_app_icon.py 同步的比例常数
    private static let ringD: CGFloat = 0.72       // 表圈外径
    private static let ringStroke: CGFloat = 0.1070
    private static let gold: CGFloat = 0.2254      // 圆角（macOS squircle）
    private static let crownW: CGFloat = 0.300
    private static let crownH: CGFloat = 0.066
    private static let crownCY: CGFloat = 0.134    // 按把中心
    private static let ringCY: CGFloat = 0.539     // 表圈中心

    var body: some View {
        let s = size
        let ringW = s * Self.ringStroke
        let innerR = (s * Self.ringD - ringW) / 2
        let cy = s * Self.ringCY

        ZStack {
            RoundedRectangle(cornerRadius: s * Self.gold, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#6CA0FF"), Color(hex: "#2858E0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 顶部按把
            Capsule()
                .fill(.white)
                .frame(width: s * Self.crownW, height: s * Self.crownH)
                .offset(y: (Self.crownCY - 0.5) * s)

            // 表圈
            Circle()
                .stroke(.white, lineWidth: ringW)
                .frame(width: s * Self.ringD - ringW, height: s * Self.ringD - ringW)
                .offset(y: (Self.ringCY - 0.5) * s)

            // 指针：12 点 + 4 点方向
            Path { p in
                let c = CGPoint(x: s / 2, y: cy)
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x, y: c.y - 0.83 * innerR))
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + 0.65 * innerR * 0.8660,
                                      y: c.y + 0.65 * innerR * 0.5))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: ringW * 0.53, lineCap: .round))

            // 中心轴
            Circle()
                .fill(.white)
                .frame(width: 0.26 * innerR, height: 0.26 * innerR)
                .offset(y: (Self.ringCY - 0.5) * s)
        }
        .frame(width: size, height: size)
    }
}
