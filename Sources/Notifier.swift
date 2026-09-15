import Foundation
import UserNotifications

// ============================================================================
//  Timer Deck — 系统通知
//  对应浏览器版 background.js 里的 chrome.notifications
// ============================================================================

final class Notifier {
    static let shared = Notifier()

    private var available: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private init() {}

    func requestPermission() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, err in
            if let err = err {
                NSLog("[TimerDeck] 通知授权失败: \(err.localizedDescription)")
            }
            _ = granted
        }
    }

    func fire(title: String, body: String? = nil) {
        guard available else {
            NSLog("[TimerDeck] 非 bundle 执行，跳过通知: \(title)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body ?? I18n.t("notifBody")
        content.sound = nil // 铃声由 SoundPlayer 负责，避免重复响

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { err in
            if let err = err {
                NSLog("[TimerDeck] 通知发送失败: \(err.localizedDescription)")
            }
        }
    }
}
