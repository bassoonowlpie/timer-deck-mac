import Foundation

// ============================================================================
//  Timer Deck — 双语字串表
//  与浏览器版的 i18n.js 逐条对应
// ============================================================================

enum I18n {
    static let langs = ["zh-Hant", "en"]

    static func setLang(_ lang: String) {
        current = dict[lang] != nil ? lang : "zh-Hant"
    }
    private(set) static var current = "zh-Hant"

    static func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        let table = dict[current] ?? dict["zh-Hant"]!
        var value = table[key] ?? dict["zh-Hant"]![key] ?? key
        for (k, v) in vars {
            value = value.replacingOccurrences(of: "{\(k)}", with: v)
        }
        return value
    }

    static func suggestions() -> [String] {
        let table = dict[current] ?? dict["zh-Hant"]!
        let raw = (current == "en" ? enSuggestions : zhSuggestions)
        _ = table
        return raw
    }

    private static let zhSuggestions = ["泡茶", "小睡", "沖咖啡", "冥想", "煮麵", "健身間歇"]
    private static let enSuggestions = ["Tea", "Nap", "Coffee", "Meditate", "Pasta", "Workout set"]

    private static let dict: [String: [String: String]] = [
        "zh-Hant": [
            "appName": "Timer Deck",
            "settings": "設定",
            "openDashboard": "開啟全頁儀表板",
            "newTimer": "新增計時器",
            "back": "返回",
            "cancel": "取消",
            "save": "儲存計時器",
            "quit": "結束 Timer Deck",

            "statusEmpty": "未有計時器",
            "statusRunningPaused": "{r} 個進行中 · {p} 個暫停",
            "statusRunningOnly": "{r} 個進行中",
            "statusPausedOnly": "{p} 個暫停",
            "statusAllStopped": "全部已停止",

            "pauseAll": "全部暫停",
            "resumeAll": "全部開始",

            "pillRunning": "{n} 進行中",

            "subEnds": "{time} 結束",
            "subEnded": "{time} 完成",
            "subNotStarted": "尚未開始",
            "subPaused": "已暫停",
            "subAlmost": "即將完成",

            "actionPause": "暫停",
            "actionResume": "繼續",
            "actionStart": "開始",

            "rename": "重新命名",
            "duplicate": "複製",
            "reset": "重設",
            "delete": "刪除",
            "clearFinished": "清除已完成",
            "moreActions": "更多操作",

            "customDuration": "自訂",
            "emptyTitle": "尚未有任何計時器",
            "emptyText": "按下方的「新增計時器」，可以同時開啟任意數量的倒數，沒有數量上限。",

            "formTitle": "新增計時器",
            "formSub": "輸入名稱，然後選擇時長",
            "nameLabel": "名稱",
            "namePlaceholder": "例如：煮麵",
            "recentUsed": "最近用過",
            "durationLabel": "時長",
            "accentLabel": "主題色",
            "optionsLabel": "選項",
            "repeat": "完成後自動重複",
            "notify": "倒數結束時通知我",
            "sound": "提示聲",
            "soundAlarm": "鬧鐘",
            "soundChime": "清脆鈴聲",
            "soundBell": "鐘聲",
            "soundPing": "短提示音",
            "soundNone": "靜音",
            "hintKeepRunning": "關閉面板後，計時器仍會繼續運作",
            "defaultName": "計時器",
            "unitHour": "小時",
            "unitMin": "分鐘",
            "unitSec": "秒",

            "dashTitle": "所有計時器",
            "dashSub": "按下卡片即可重新命名、重設或刪除",
            "filterAll": "全部",
            "filterRunning": "進行中",
            "filterPaused": "已暫停",
            "filterFinished": "已完成",
            "countTimers": "{n} 個計時器",
            "countRunning": "{n} 個進行中",
            "metaEnds": "{time} 結束 · 總長 {total}",
            "metaEnded": "{time} 完成 · 總長 {total}",
            "metaPaused": "已暫停 · 總長 {total}",
            "metaNotStarted": "尚未開始 · 總長 {total}",
            "noMatch": "沒有符合此篩選條件的計時器。",
            "btnStart": "開始",
            "btnPause": "暫停",
            "btnResume": "繼續",
            "btnRestart": "重新開始",

            "optionsTitle": "設定",
            "optionsSub": "外觀、語言及其他偏好設定",
            "appearance": "外觀",
            "themeDark": "深色",
            "themeLight": "淺色",
            "themeSystem": "跟隨系統",
            "language": "語言",
            "other": "其他",
            "optBadge": "在選單列顯示狀態",
            "optBadgeSub": "只有一個計時器時顯示剩餘時間，多個時顯示數量",
            "optNotify": "倒數結束時通知我",
            "optNotifySub": "新增的計時器會預設開啟",
            "optSound": "提示聲",
            "optSoundSub": "按一下切換下一種，並套用到所有計時器",
            "hintInstant": "設定會即時套用",
            "version": "版本",

            "toastSaved": "已儲存",
            "toastDeleted": "已刪除",
            "toastDeletedNamed": "已刪除「{name}」",
            "toastClearedFinished": "已刪除 {n} 個已完成的計時器",
            "toastReset": "已重設",
            "toastDuplicated": "已複製",
            "toastRenamed": "已重新命名",
            "removeSuggestion": "移除這個名稱建議",
            "restoreSuggestions": "還原建議名稱",
            "undo": "復原",

            "notifTitle": "{name} 時間到！",
            "notifBody": "倒數已經結束。",
        ],

        "en": [
            "appName": "Timer Deck",
            "settings": "Settings",
            "openDashboard": "Open dashboard",
            "newTimer": "New timer",
            "back": "Back",
            "cancel": "Cancel",
            "save": "Save timer",
            "quit": "Quit Timer Deck",

            "statusEmpty": "No timers yet",
            "statusRunningPaused": "{r} running · {p} paused",
            "statusRunningOnly": "{r} running",
            "statusPausedOnly": "{p} paused",
            "statusAllStopped": "All stopped",

            "pauseAll": "Pause all",
            "resumeAll": "Start all",

            "pillRunning": "{n} running",

            "subEnds": "Ends {time}",
            "subEnded": "Finished {time}",
            "subNotStarted": "Not started",
            "subPaused": "Paused",
            "subAlmost": "Almost done",

            "actionPause": "pause",
            "actionResume": "resume",
            "actionStart": "start",

            "rename": "Rename",
            "duplicate": "Duplicate",
            "reset": "Reset",
            "delete": "Delete",
            "clearFinished": "Clear finished",
            "moreActions": "More actions",

            "customDuration": "Custom",
            "emptyTitle": "No timers yet",
            "emptyText": "Hit New timer below — add as many countdowns as you like.",

            "formTitle": "New timer",
            "formSub": "Name it, then pick a length",
            "nameLabel": "Name",
            "namePlaceholder": "e.g. Pasta",
            "recentUsed": "Recently used",
            "durationLabel": "Duration",
            "accentLabel": "Accent",
            "optionsLabel": "Options",
            "repeat": "Repeat when finished",
            "notify": "Notify me when it ends",
            "sound": "Sound",
            "soundAlarm": "Alarm",
            "soundChime": "Chime",
            "soundBell": "Bell",
            "soundPing": "Ping",
            "soundNone": "Silent",
            "hintKeepRunning": "Timers keep running after you close this panel",
            "defaultName": "Timer",
            "unitHour": "hr",
            "unitMin": "min",
            "unitSec": "sec",

            "dashTitle": "All timers",
            "dashSub": "Tap a card to rename, reset or delete",
            "filterAll": "All",
            "filterRunning": "Running",
            "filterPaused": "Paused",
            "filterFinished": "Finished",
            "countTimers": "{n} timers",
            "countRunning": "{n} running",
            "metaEnds": "Ends {time} · {total} total",
            "metaEnded": "Finished {time} · {total} total",
            "metaPaused": "Paused · {total} total",
            "metaNotStarted": "Not started · {total} total",
            "noMatch": "No timers match this filter.",
            "btnStart": "Start",
            "btnPause": "Pause",
            "btnResume": "Resume",
            "btnRestart": "Restart",

            "optionsTitle": "Settings",
            "optionsSub": "Appearance, language and other preferences",
            "appearance": "Appearance",
            "themeDark": "Dark",
            "themeLight": "Light",
            "themeSystem": "System",
            "language": "Language",
            "other": "Other",
            "optBadge": "Show status on the menu bar icon",
            "optBadgeSub": "Remaining time when one timer runs, count when several",
            "optNotify": "Notify me when a timer ends",
            "optNotifySub": "New timers turn this on by default",
            "optSound": "Ringtone",
            "optSoundSub": "Tap to cycle — applied to every timer",
            "hintInstant": "Changes apply straight away",
            "version": "Version",

            "toastSaved": "Saved",
            "toastDeleted": "Deleted",
            "toastDeletedNamed": "Deleted “{name}”",
            "toastClearedFinished": "Removed {n} finished timers",
            "toastReset": "Reset",
            "toastDuplicated": "Duplicated",
            "toastRenamed": "Renamed",
            "removeSuggestion": "Remove this suggestion",
            "restoreSuggestions": "Restore suggestions",
            "undo": "Undo",

            "notifTitle": "{name} is up!",
            "notifBody": "Your countdown just finished.",
        ],
    ]

    /// 铃声显示名称
    static func soundLabel(_ tone: String) -> String {
        switch tone {
        case "alarm": return t("soundAlarm")
        case "chime": return t("soundChime")
        case "bell": return t("soundBell")
        case "ping": return t("soundPing")
        default: return t("soundNone")
        }
    }

    /// 「1 小時 15 分鐘」這種組合
    static func durationLabel(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) \(t("unitHour"))") }
        if m > 0 { parts.append("\(m) \(t("unitMin"))") }
        if s > 0 { parts.append("\(s) \(t("unitSec"))") }
        if parts.isEmpty { parts.append("0 \(t("unitSec"))") }
        return parts.joined(separator: " ")
    }
}
