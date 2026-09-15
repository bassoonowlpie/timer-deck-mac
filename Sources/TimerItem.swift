import Foundation

// ============================================================================
//  Timer Deck — 数据模型
//  与浏览器扩展的 timer 物件一一对应（时间一律用 epoch 毫秒，降低移植风险）
// ============================================================================

enum TimerStatus: String, Codable {
    case idle
    case running
    case paused
    case finished

    var label: String { rawValue }
}

struct TimerItem: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// 总时长（毫秒）
    var duration: Double
    /// 暂停时保留的剩余时间（毫秒）
    var remaining: Double
    /// 结束时刻（epoch 毫秒），只有 running 才有
    var endsAt: Double?
    var status: TimerStatus
    var accent: String
    var isRepeating: Bool
    var notify: Bool
    var sound: String
    var createdAt: Double
    var finishedAt: Double?
    /// 每完成一圈就盖一次章，用来判断「这一圈有没有响过」
    var rangAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, duration, remaining, endsAt, status, accent
        case isRepeating = "repeat"
        case notify, sound, createdAt, finishedAt, rangAt
    }

    init(
        id: String,
        name: String,
        duration: Double,
        remaining: Double,
        endsAt: Double? = nil,
        status: TimerStatus = .idle,
        accent: String,
        isRepeating: Bool = false,
        notify: Bool = true,
        sound: String,
        createdAt: Double,
        finishedAt: Double? = nil,
        rangAt: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.remaining = remaining
        self.endsAt = endsAt
        self.status = status
        self.accent = accent
        self.isRepeating = isRepeating
        self.notify = notify
        self.sound = sound
        self.createdAt = createdAt
        self.finishedAt = finishedAt
        self.rangAt = rangAt
    }
}

// ---------------------------------------------------------------------------
//  显示用的即时视图（每次刷新重新推导，绝不写回）
// ---------------------------------------------------------------------------

enum RingTone {
    case run, soon, paused, idle, done
}

struct TimerView {
    var id: String
    var name: String
    var accent: String
    var status: TimerStatus
    var remaining: Double
    var progress: Double
    var endsAt: Double?
    var finishedAt: Double?
    var duration: Double
    var isRepeating: Bool
}

// ---------------------------------------------------------------------------
//  设定
// ---------------------------------------------------------------------------

enum ThemePref: String, Codable, CaseIterable {
    case dark, light, system
}

struct Settings: Codable, Equatable {
    var theme: String = "dark"
    var lang: String = "zh-Hant"
    var badge: Bool = true
    var notify: Bool = true
    var sound: String = "alarm"
    var soundVersion: Int = 2
    var recentNames: [String] = []
    var recentDurations: [Double] = []
    /// 被使用者从表单里删掉的原生名称建议（删掉就不再出现）
    var hiddenNames: [String] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case theme, lang, badge, notify, sound, soundVersion, recentNames, recentDurations, hiddenNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try? c.decode(String.self, forKey: .theme)) ?? "dark"
        lang = (try? c.decode(String.self, forKey: .lang)) ?? "zh-Hant"
        badge = (try? c.decode(Bool.self, forKey: .badge)) ?? true
        notify = (try? c.decode(Bool.self, forKey: .notify)) ?? true
        sound = (try? c.decode(String.self, forKey: .sound)) ?? "alarm"
        soundVersion = (try? c.decode(Int.self, forKey: .soundVersion)) ?? 2
        recentNames = (try? c.decode([String].self, forKey: .recentNames)) ?? []
        recentDurations = (try? c.decode([Double].self, forKey: .recentDurations)) ?? []
        hiddenNames = (try? c.decode([String].self, forKey: .hiddenNames)) ?? []
    }
}

// ---------------------------------------------------------------------------
//  磁盘格式
// ---------------------------------------------------------------------------

struct DeckFile: Codable {
    var timers: [TimerItem]
    var settings: Settings
}
