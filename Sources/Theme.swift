import SwiftUI

// ============================================================================
//  Timer Deck — 主题色
//  数值直接取自浏览器版的 tokens.css，深浅两套
// ============================================================================

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

struct Theme {
    let isDark: Bool

    // 品牌色（两套主题相同）
    let accent = Color(hex: "#3D7BFF")
    let accentHover = Color(hex: "#5490FF")
    let accentTint = Color(hex: "#3D7BFF").opacity(0.14)
    let coral = Color(hex: "#FF6B6B")
    let dangerTint = Color(hex: "#FF6B6B").opacity(0.14)

    var bg: Color { isDark ? Color(hex: "#1E1E1E") : Color(hex: "#FFFFFF") }
    var bgPage: Color { isDark ? Color(hex: "#1B1B1B") : Color(hex: "#F4F4F7") }
    var surface: Color { isDark ? Color(hex: "#262626") : Color(hex: "#FFFFFF") }
    var surface2: Color { isDark ? Color(hex: "#333333") : Color(hex: "#F1F1F4") }
    var surface3: Color { isDark ? Color(hex: "#3A3A3A") : Color(hex: "#EDEDF1") }
    var surfaceHover: Color { isDark ? Color(hex: "#2E2E2E") : Color(hex: "#F7F7FA") }
    var border: Color { isDark ? Color(hex: "#3A3A3A") : Color(hex: "#E4E4EA") }
    var divider: Color { isDark ? Color(hex: "#2F2F2F") : Color(hex: "#ECECF1") }

    var text: Color { isDark ? Color(hex: "#F0F0F0") : Color(hex: "#16161A") }
    var textDim: Color { isDark ? Color(hex: "#C8C8C8") : Color(hex: "#3F3F47") }
    var textMute: Color { isDark ? Color(hex: "#7C7C7C") : Color(hex: "#8A8A8E") }
    var textFaint: Color { isDark ? Color(hex: "#5A5A62") : Color(hex: "#A9A9AE") }

    var ringTrack: Color { isDark ? Color(hex: "#333333") : Color(hex: "#E3E3E8") }
    var ok: Color { isDark ? Color(hex: "#5BCFC5") : Color(hex: "#0FA79A") }
    var warn: Color { isDark ? Color(hex: "#FFA94D") : Color(hex: "#E8890C") }
    var idleDot: Color { isDark ? Color(hex: "#8A8A8A") : Color(hex: "#A9A9AE") }

    /// 把主题设定解析成实际明暗
    static func resolve(_ pref: String, systemIsDark: Bool) -> Theme {
        switch pref {
        case "light": return Theme(isDark: false)
        case "dark": return Theme(isDark: true)
        default: return Theme(isDark: systemIsDark)
        }
    }

    func ringColor(tone: RingTone, accentHex: String) -> Color {
        switch tone {
        case .soon: return warn
        case .done: return ok
        case .paused: return idleDot
        case .idle: return idleDot
        case .run: return Color(hex: accentHex)
        }
    }
}

// 圆角与间距，对齐 CSS 的 token
enum Metrics {
    static let rXS: CGFloat = 6
    static let rSM: CGFloat = 8
    static let rMD: CGFloat = 10
    static let rLG: CGFloat = 12
    static let rXL: CGFloat = 14
    static let r2XL: CGFloat = 16
    static let r3XL: CGFloat = 20
}
