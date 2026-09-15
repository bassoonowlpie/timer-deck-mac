import SwiftUI

// ============================================================================
//  Timer Deck — 共用视觉元件
//  对应浏览器版的 40x40 进度环、状态胶囊、方形图示按钮
// ============================================================================

/// 40×40 的进度环 ＋ 中心图示
struct RingView: View {
    let tone: RingTone
    let progress: Double
    let accentHex: String
    let theme: Theme
    var size: CGFloat = 40

    private var ringColor: Color { theme.ringColor(tone: tone, accentHex: accentHex) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.ringTrack, lineWidth: size * 0.075)

            if tone != .idle {
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            glyph
                .foregroundStyle(glyphColor)
                .font(.system(size: size * 0.34, weight: .bold))
        }
        .frame(width: size, height: size)
    }

    private var glyphColor: Color {
        switch tone {
        case .soon: return theme.warn
        case .done: return theme.ok
        case .paused, .idle: return theme.textDim
        case .run: return theme.text
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch tone {
        case .done:
            Image(systemName: "checkmark")
        case .paused, .idle:
            Image(systemName: "play.fill")
                .offset(x: size * 0.02)
        case .run, .soon:
            Image(systemName: "pause.fill")
        }
    }
}

/// 状态胶囊：进行中 / 暂停 / 已完成
struct PillView: View {
    let text: String
    let tone: RingTone
    let theme: Theme

    private var color: Color {
        switch tone {
        case .soon: return theme.warn
        case .done: return theme.ok
        case .paused, .idle: return theme.textMute
        case .run: return theme.accent
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// 方形图示按钮（标题栏 / 底部工具列）
struct IconBtn: View {
    let systemName: String
    let theme: Theme
    var help: String? = nil
    var danger: Bool = false
    /// 方形按钮的边长。列表行里塞得比较密，会用到 25 这种小尺寸
    var size: CGFloat = 28
    var action: () -> Void

    @LocalState private var hovering = false

    private var foreground: Color {
        if danger { return hovering ? theme.coral : theme.coral.opacity(0.85) }
        return hovering ? theme.text : theme.textMute
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.46, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.rSM)
                        .fill(hovering ? (danger ? theme.dangerTint : theme.surface2) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help ?? "")
    }
}

/// 主按钮 / 次按钮
struct DeckButton: View {
    let title: String
    let theme: Theme
    var systemImage: String? = nil
    var primary: Bool = true
    var danger: Bool = false
    var fullWidth: Bool = false
    var action: () -> Void

    @LocalState private var hovering = false

    private var bg: Color {
        if primary { return hovering ? theme.accentHover : theme.accent }
        if danger { return hovering ? theme.dangerTint : theme.surface2 }
        return hovering ? theme.surface3 : theme.surface2
    }

    private var fg: Color {
        if primary { return .white }
        if danger { return theme.coral }
        return theme.text
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let s = systemImage {
                    Image(systemName: s).font(.system(size: 12, weight: .semibold))
                }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(bg, in: RoundedRectangle(cornerRadius: Metrics.rMD))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// 可选取的小胶囊（时长模板 / 名称建议）
///
/// 三种状态刻意用不同的视觉，避免混淆：
///   已选中   —— 蓝底 + 蓝字 + 蓝框。整组同一时间只会有一个是这个样子。
///   最近用过 —— 灰字，前面加一个小闹钟记号。不再用蓝色，
///               否则会跟「已选中」看起来一模一样（之前就是这样，会见到两个蓝字）。
///   一般     —— 灰字。
struct ChipView: View {
    let text: String
    let theme: Theme
    var selected: Bool = false
    var recent: Bool = false
    /// 有传的话，尾端会预留一个删除键，hover 时才浮现
    var onRemove: (() -> Void)? = nil
    /// 开发预览用：强制把删除键显示出来（离屏渲染没有 hover）
    var forceHover: Bool = false
    var action: () -> Void

    @LocalState private var hovering = false

    private var showRemove: Bool { onRemove != nil && (hovering || forceHover) }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                if recent && !selected {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textFaint)
                }

                Text(text)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? theme.accent : theme.textDim)
            }
            .padding(.leading, 10)
            .padding(.trailing, onRemove == nil ? 10 : 5)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { action() }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.textFaint)
                        .frame(width: 14, height: 14)
                        .background(theme.surface3, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(I18n.t("removeSuggestion"))
                .padding(.trailing, 6)
                .opacity(showRemove ? 1 : 0)
                .allowsHitTesting(showRemove)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Metrics.rPill)
                .fill(selected ? theme.accentTint : (hovering ? theme.surface2 : theme.surface2.opacity(0.6)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.rPill)
                .stroke(
                    selected ? theme.accent.opacity(0.7) : theme.border.opacity(0.6),
                    lineWidth: selected ? 1.2 : 1
                )
        )
        .help(recent ? I18n.t("recentUsed") : "")
        .onHover { hovering = $0 }
    }
}

extension Metrics {
    static let rPill: CGFloat = 99
}

/// 自定义开关（对应浏览器版的 .switch，视觉与行为都更贴近原设计）
struct DeckSwitch: View {
    let isOn: Bool
    let theme: Theme
    var onChange: (Bool) -> Void

    private let trackW: CGFloat = 38
    private let trackH: CGFloat = 22

    var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? theme.accent : theme.surface3)
                    .frame(width: trackW, height: trackH)

                Circle()
                    .fill(.white)
                    .frame(width: trackH - 6, height: trackH - 6)
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .offset(x: isOn ? trackW - trackH + 3 : 3)
            }
            .animation(.easeOut(duration: 0.16), value: isOn)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
