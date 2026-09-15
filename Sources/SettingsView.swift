import SwiftUI

// ============================================================================
//  Timer Deck — 设定
//  对应浏览器版的 options.html
// ============================================================================

struct SettingsView: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme.resolve(store.settings.theme, systemIsDark: scheme == .dark) }

    var body: some View {
        ZStack {
            theme.bgPage.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                header
                appearanceSection
                languageSection
                otherSection
                Spacer(minLength: 0)
                footer
            }
            .padding(22)
        }
        .frame(width: 460, height: 560)
    }

    private var header: some View {
        HStack(spacing: 11) {
            LogoMark(size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(I18n.t("optionsTitle"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(I18n.t("optionsSub"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMute)
            }
            Spacer()
        }
    }

    // ------------------------------------------------------------ 外观 --
    private var appearanceSection: some View {
        section(title: I18n.t("appearance")) {
            HStack(spacing: 8) {
                themeOption("dark", I18n.t("themeDark"))
                themeOption("light", I18n.t("themeLight"))
                themeOption("system", I18n.t("themeSystem"))
                Spacer()
            }
        }
    }

    private func themeOption(_ value: String, _ label: String) -> some View {
        let selected = store.settings.theme == value
        return Button {
            store.updateSettings { $0.theme = value }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? theme.accent : theme.textDim)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.rSM)
                        .fill(selected ? theme.accentTint : theme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rSM)
                        .stroke(selected ? theme.accent.opacity(0.5) : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // ------------------------------------------------------------ 语言 --
    private var languageSection: some View {
        section(title: I18n.t("language")) {
            HStack(spacing: 8) {
                ForEach(I18n.langs, id: \.self) { lang in
                    let selected = store.settings.lang == lang
                    Button {
                        store.updateSettings { $0.lang = lang }
                    } label: {
                        Text(lang == "zh-Hant" ? "繁體中文" : "English")
                            .font(.system(size: 12, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? theme.accent : theme.textDim)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: Metrics.rSM)
                                    .fill(selected ? theme.accentTint : theme.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Metrics.rSM)
                                    .stroke(selected ? theme.accent.opacity(0.5) : theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // ------------------------------------------------------------ 其他 --
    private var otherSection: some View {
        section(title: I18n.t("other")) {
            VStack(spacing: 0) {
                settingRow(title: I18n.t("optBadge"), sub: I18n.t("optBadgeSub")) {
                    DeckSwitch(isOn: store.settings.badge, theme: theme) { v in
                        store.updateSettings { $0.badge = v }
                    }
                }
                Divider().overlay(theme.divider)

                settingRow(title: I18n.t("optNotify"), sub: I18n.t("optNotifySub")) {
                    DeckSwitch(isOn: store.settings.notify, theme: theme) { v in
                        store.updateSettings { $0.notify = v }
                        if v { Notifier.shared.requestPermission() }
                    }
                }
                Divider().overlay(theme.divider)

                settingRow(title: I18n.t("optSound"), sub: I18n.t("optSoundSub")) {
                    Button {
                        let all = Engine.soundTones + ["none"]
                        let idx = all.firstIndex(of: store.settings.sound) ?? 0
                        let next = all[(idx + 1) % all.count]
                        Actions.setSoundForAll(next)
                        SoundPlayer.shared.preview(next)
                    } label: {
                        Text(I18n.soundLabel(store.settings.sound))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.textDim)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(theme.surface2.opacity(theme.isDark ? 0.5 : 0.7), in: RoundedRectangle(cornerRadius: Metrics.rLG))
        }
    }

    private var footer: some View {
        HStack {
            Text("\(I18n.t("version")) \(AppInfo.version)")
                .font(.system(size: 11))
                .foregroundStyle(theme.textFaint)
            Spacer()
            DeckButton(title: I18n.t("quit"), theme: theme, systemImage: "power", primary: false, danger: true) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // ---------------------------------------------------------- 版型 --
    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textDim)
            content()
        }
    }

    private func settingRow<T: View>(title: String, sub: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textMute)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.1"
    }
}
