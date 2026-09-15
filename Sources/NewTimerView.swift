import SwiftUI

// ============================================================================
//  Timer Deck — 新增计时器表单
//  对应浏览器版 popup 的 form 视图
// ============================================================================

struct NewTimerView: View {
    let theme: Theme
    /// 回呼：参数代表是否真的储存了
    var onDone: (Bool) -> Void

    @ObservedObject private var store = Store.shared

    @LocalState private var name = ""
    @LocalState private var hour = 0
    @LocalState private var minute = 15
    @LocalState private var second = 0
    @LocalState private var accent = Engine.accents[0]
    @LocalState private var isRepeating = false
    @LocalState private var notify = true
    @LocalState private var sound = Engine.defaultSound
    @FocusState private var nameFocused: Bool

    private var totalSeconds: Double {
        Double(hour * 3600 + minute * 60 + second)
    }

    private var suggestionChips: [String] {
        let hidden = Set(store.settings.hiddenNames)
        let recents = store.settings.recentNames.prefix(4).map { $0 }.filter { !hidden.contains($0) }
        let builtin = I18n.suggestions().filter { !recents.contains($0) && !hidden.contains($0) }
        return recents + Array(builtin.prefix(max(0, 6 - recents.count)))
    }

    private var durationChips: [(label: String, seconds: Double, recent: Bool)] {
        var out: [(String, Double, Bool)] = Engine.presetsMin.map { m in
            let s = Double(m) * 60
            let label = m >= 60 ? "1 \(I18n.t("unitHour"))" : "\(m) \(I18n.t("unitMin"))"
            return (label, s, false)
        }
        let presetSeconds = Engine.presetsMin.map { Double($0) * 60 }
        for sec in store.settings.recentDurations where !presetSeconds.contains(sec) {
            out.append((I18n.durationLabel(seconds: sec), sec, true))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.divider)

            ScrollView { formFields }

            Divider().overlay(theme.divider)
            footer
        }
        .background(theme.bg)
        .onAppear { nameFocused = true }
    }

    /// 表单主体（独立出来，方便离屏渲染逐项检查）
    var formFields: some View {
        VStack(alignment: .leading, spacing: 15) {
            nameField
            if !suggestionChips.isEmpty || !store.settings.hiddenNames.isEmpty { suggestions }
            durationSection
            accentSection
            optionsSection
            hintRow
        }
        .padding(14)
    }

    // ------------------------------------------------------------ 标题 --
    private var header: some View {
        HStack(spacing: 10) {
            IconBtn(systemName: "chevron.left", theme: theme, help: I18n.t("back")) {
                onDone(false)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(I18n.t("formTitle"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(I18n.t("formSub"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMute)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // ------------------------------------------------------------ 名称 --
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(I18n.t("nameLabel"))
            HStack(spacing: 6) {
                TextField(I18n.t("namePlaceholder"), text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text)
                    .focused($nameFocused)
                    .onSubmit { save() }
                    .onChange(of: name) { newValue in
                        if newValue.count > 24 { name = String(newValue.prefix(24)) }
                    }
                if !name.isEmpty {
                    Button {
                        name = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(theme.surface2, in: RoundedRectangle(cornerRadius: Metrics.rSM))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rSM)
                    .stroke(nameFocused ? theme.accent.opacity(0.6) : theme.border, lineWidth: 1)
            )
        }
    }

    private var suggestions: some View {
        FlowRow(spacing: 6) {
            ForEach(suggestionChips, id: \.self) { s in
                ChipView(
                    text: s,
                    theme: theme,
                    selected: name == s,
                    recent: store.settings.recentNames.contains(s),
                    onRemove: { removeSuggestion(s) }
                ) {
                    name = s
                }
            }

            // 删过内建建议之后，留一条还原的退路
            if !store.settings.hiddenNames.isEmpty {
                Button {
                    store.clearHiddenNames()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .semibold))
                        Text(I18n.t("restoreSuggestions"))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(theme.textFaint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.surface2.opacity(0.5), in: Capsule())
                    .overlay(Capsule().stroke(theme.border.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func removeSuggestion(_ s: String) {
        store.removeNameSuggestion(s)
        if name == s { name = "" }
    }

    // ------------------------------------------------------------ 时长 --
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(I18n.t("durationLabel"))

            FlowRow(spacing: 6) {
                ForEach(Array(durationChips.enumerated()), id: \.offset) { _, chip in
                    ChipView(
                        text: chip.label,
                        theme: theme,
                        selected: abs(totalSeconds - chip.seconds) < 0.5,
                        recent: chip.recent
                    ) {
                        applySeconds(chip.seconds)
                    }
                }
            }

            // 自订：时 / 分 / 秒
            VStack(alignment: .leading, spacing: 7) {
                Text(I18n.t("customDuration"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textMute)

                stepperRow(unit: I18n.t("unitHour"), value: $hour, range: 0...10, step: 1)
                stepperRow(unit: I18n.t("unitMin"), value: $minute, range: 0...600, step: 1)
                stepperRow(unit: I18n.t("unitSec"), value: $second, range: 0...59, step: 5)

                Text(Engine.formatSpan(totalSeconds * 1000, lang: I18n.current))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(totalSeconds > 0 ? theme.accent : theme.textFaint)
                    .padding(.top, 1)
            }
            .padding(11)
            .background(theme.surface2.opacity(theme.isDark ? 0.55 : 0.7), in: RoundedRectangle(cornerRadius: Metrics.rLG))
        }
    }

    private func stepperRow(unit: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        HStack(spacing: 8) {
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(theme.textMute)
                .frame(width: 34, alignment: .leading)

            HStack(spacing: 0) {
                stepButton("minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }

                TextField("", value: value, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .onChange(of: value.wrappedValue) { newValue in
                        if newValue < range.lowerBound { value.wrappedValue = range.lowerBound }
                        if newValue > range.upperBound { value.wrappedValue = range.upperBound }
                    }

                stepButton("plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
            }
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Metrics.rSM))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rSM)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textDim)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applySeconds(_ s: Double) {
        let total = Int(s)
        hour = total / 3600
        minute = (total % 3600) / 60
        second = total % 60
    }

    // ---------------------------------------------------------- 主题色 --
    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(I18n.t("accentLabel"))
            HStack(spacing: 9) {
                ForEach(Engine.accents, id: \.self) { hex in
                    Button {
                        accent = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                            if accent == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(accent == hex ? theme.text.opacity(0.7) : .clear, lineWidth: 2)
                                .frame(width: 30, height: 30)
                        )
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // ------------------------------------------------------------ 选项 --
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(I18n.t("optionsLabel"))

            VStack(spacing: 0) {
                optionRow(title: I18n.t("repeat")) {
                    DeckSwitch(isOn: isRepeating, theme: theme) { isRepeating = $0 }
                }
                Divider().overlay(theme.divider)
                optionRow(title: I18n.t("notify")) {
                    DeckSwitch(isOn: notify, theme: theme) { notify = $0 }
                }
                Divider().overlay(theme.divider)
                optionRow(title: I18n.t("sound")) {
                    Button {
                        sound = nextSound(sound)
                        SoundPlayer.shared.preview(sound)
                    } label: {
                        Text(I18n.soundLabel(sound))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.textDim)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(theme.surface2.opacity(theme.isDark ? 0.55 : 0.7), in: RoundedRectangle(cornerRadius: Metrics.rLG))
        }
    }

    private func optionRow<T: View>(title: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.textDim)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private func nextSound(_ current: String) -> String {
        let all = Engine.soundTones + ["none"]
        guard let idx = all.firstIndex(of: current) else { return all[0] }
        return all[(idx + 1) % all.count]
    }

    private var hintRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text(I18n.t("hintKeepRunning"))
                .font(.system(size: 10))
        }
        .foregroundStyle(theme.textFaint)
    }

    // ------------------------------------------------------------ 底部 --
    private var footer: some View {
        HStack(spacing: 8) {
            DeckButton(title: I18n.t("cancel"), theme: theme, primary: false, fullWidth: true) {
                onDone(false)
            }
            DeckButton(title: I18n.t("save"), theme: theme, primary: true, fullWidth: true) {
                save()
            }
            .disabled(totalSeconds < 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.textMute)
    }

    private func save() {
        guard totalSeconds >= 1 else { return }
        let finalName = name.trimmingCharacters(in: .whitespaces)
        // 新建立的计时器立即开始倒数 —— 想停就按进度环
        Actions.create(
            name: finalName,
            seconds: totalSeconds,
            accent: accent,
            isRepeating: isRepeating,
            notify: notify,
            sound: sound
        )
        if !finalName.isEmpty { store.rememberName(finalName) }
        store.rememberDuration(seconds: totalSeconds)
        onDone(true)
    }
}

// ============================================================================
//  自动换行的横向排列（chips 用）
// ============================================================================

struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
