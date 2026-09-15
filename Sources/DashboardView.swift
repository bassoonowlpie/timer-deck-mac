import SwiftUI

// ============================================================================
//  Timer Deck — 全页仪表板
//  对应浏览器版的 dashboard.html
// ============================================================================

enum DeckFilter: String, CaseIterable {
    case all, running, paused, finished

    var label: String {
        switch self {
        case .all: return I18n.t("filterAll")
        case .running: return I18n.t("filterRunning")
        case .paused: return I18n.t("filterPaused")
        case .finished: return I18n.t("filterFinished")
        }
    }
}

struct DashboardView: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.colorScheme) private var scheme
    @LocalState private var filter: DeckFilter = .all
    @LocalState private var renameID: String?
    @LocalState private var renameText = ""

    private var theme: Theme { Theme.resolve(store.settings.theme, systemIsDark: scheme == .dark) }

    private var visible: [TimerItem] {
        store.timers.filter { t in
            let s = Engine.view(t, now: store.now).status
            switch filter {
            case .all: return true
            case .running: return s == .running
            case .paused: return s == .paused || s == .idle
            case .finished: return s == .finished
            }
        }
    }

    var body: some View {
        ZStack {
            theme.bgPage.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                filterBar
                content
            }
        }
        .frame(minWidth: 620, minHeight: 460)
        .sheet(isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
            renameSheet
        }
    }

    // ------------------------------------------------------------ 标题 --
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            LogoMark(size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(I18n.t("dashTitle"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(I18n.t("dashSub"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMute)
            }
            Spacer()

            let s = Actions.summary(now: store.now)
            if s.running > 0 {
                PillView(text: I18n.t("countRunning", ["n": "\(s.running)"]), tone: .run, theme: theme)
            }
            Text(I18n.t("countTimers", ["n": "\(s.total)"]))
                .font(.system(size: 12))
                .foregroundStyle(theme.textMute)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var filterBar: some View {
        HStack(spacing: 7) {
            ForEach(DeckFilter.allCases, id: \.self) { f in
                ChipView(text: f.label, theme: theme, selected: filter == f) {
                    withAnimation(.easeOut(duration: 0.15)) { filter = f }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    // ------------------------------------------------------------ 内容 --
    @ViewBuilder
    private var content: some View {
        if store.timers.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(theme.textFaint)
                Text(I18n.t("emptyTitle"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.textDim)
                Text(I18n.t("emptyText"))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if visible.isEmpty {
            VStack {
                Text(I18n.t("noMatch"))
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textMute)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 258), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(visible) { timer in
                        TimerCardView(
                            timer: timer,
                            now: store.now,
                            theme: theme,
                            onToggle: { Actions.toggle(timer.id) },
                            onReset: { Actions.reset(timer.id) },
                            onDuplicate: { Actions.duplicate(timer.id) },
                            onRename: {
                                renameText = timer.name
                                renameID = timer.id
                            },
                            onDelete: { Actions.remove(timer.id) }
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(I18n.t("rename"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text)
            TextField(I18n.t("namePlaceholder"), text: $renameText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(theme.surface2, in: RoundedRectangle(cornerRadius: Metrics.rSM))
                .onSubmit { commitRename() }
            HStack {
                Spacer()
                DeckButton(title: I18n.t("cancel"), theme: theme, primary: false) { renameID = nil }
                DeckButton(title: I18n.t("save"), theme: theme, primary: true) { commitRename() }
            }
        }
        .padding(18)
        .frame(width: 300)
        .background(theme.bg)
    }

    private func commitRename() {
        if let id = renameID { Actions.rename(id, to: renameText) }
        renameID = nil
    }
}

// ============================================================================
//  仪表板卡片
// ============================================================================

struct TimerCardView: View {
    let timer: TimerItem
    let now: Double
    let theme: Theme
    var onToggle: () -> Void
    var onReset: () -> Void
    var onDuplicate: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void

    @LocalState private var hovering = false
    @LocalState private var showActions = false

    private var v: TimerView { Engine.view(timer, now: now) }
    private var tone: RingTone { Engine.tone(for: v) }
    private var accentColor: Color { Color(hex: timer.accent) }

    private var accentTint: Color {
        guard v.status != .idle else { return .clear }
        return accentColor.opacity(theme.isDark ? 0.08 : 0.05)
    }

    private var meta: String {
        let total = Engine.formatSpan(timer.duration, lang: I18n.current)
        switch v.status {
        case .running:
            if let endsAt = v.endsAt {
                return I18n.t("metaEnds", ["time": Engine.clockTime(endsAt, lang: I18n.current), "total": total])
            }
            return I18n.t("metaNotStarted", ["total": total])
        case .finished:
            let at = v.finishedAt ?? now
            return I18n.t("metaEnded", ["time": Engine.clockTime(at, lang: I18n.current), "total": total])
        case .paused:
            return I18n.t("metaPaused", ["total": total])
        case .idle:
            return I18n.t("metaNotStarted", ["total": total])
        }
    }

    private var primaryLabel: String {
        switch v.status {
        case .running: return I18n.t("btnPause")
        case .paused: return I18n.t("btnResume")
        case .idle: return I18n.t("btnStart")
        case .finished: return I18n.t("btnRestart")
        }
    }

    /// 展开后的单个操作按钮
    private func cardAction(
        _ title: String,
        _ icon: String,
        _ action: @escaping () -> Void,
        danger: Bool = false
    ) -> some View {
        Button {
            action()
            withAnimation(.easeOut(duration: 0.15)) { showActions = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(danger ? theme.coral : theme.textDim)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rXS)
                    .fill(danger ? theme.dangerTint : theme.surface2)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                RingView(tone: tone, progress: v.progress, accentHex: timer.accent, theme: theme, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(timer.name.isEmpty ? I18n.t("defaultName") : timer.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        if timer.isRepeating {
                            Image(systemName: "repeat")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textFaint)
                        }
                    }
                    Text(Engine.formatClock(v.remaining))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(v.status == .finished ? theme.textMute : theme.text)
                }

                Spacer(minLength: 0)

                IconBtn(systemName: "ellipsis", theme: theme, help: I18n.t("moreActions")) {
                    withAnimation(.easeOut(duration: 0.15)) { showActions.toggle() }
                }
            }

            Text(meta)
                .font(.system(size: 11))
                .foregroundStyle(theme.textMute)
                .lineLimit(1)

            HStack(spacing: 7) {
                DeckButton(
                    title: primaryLabel,
                    theme: theme,
                    systemImage: v.status == .running ? "pause.fill" : "play.fill",
                    primary: true
                ) {
                    onToggle()
                }
                if v.status != .idle {
                    DeckButton(title: I18n.t("reset"), theme: theme, systemImage: "arrow.counterclockwise", primary: false) {
                        onReset()
                    }
                }
                Spacer()
            }

            if showActions {
                Rectangle().fill(theme.divider).frame(height: 1)
                HStack(spacing: 6) {
                    cardAction(I18n.t("rename"), "pencil", onRename)
                    cardAction(I18n.t("duplicate"), "doc.on.doc", onDuplicate)
                    Spacer(minLength: 0)
                    cardAction(I18n.t("delete"), "trash", onDelete, danger: true)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Metrics.r2XL)
                .fill(theme.surface)
        )
        .background(
            RoundedRectangle(cornerRadius: Metrics.r2XL)
                .fill(accentTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.r2XL)
                .stroke(hovering ? theme.border : theme.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.07), radius: hovering ? 12 : 4, y: hovering ? 6 : 2)
        .animation(.easeOut(duration: 0.15), value: hovering)
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
