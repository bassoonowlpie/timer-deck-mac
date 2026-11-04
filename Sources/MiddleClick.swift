import Foundation

// ============================================================================
//  Timer Deck — 中鍵（滑鼠滾軸按鈕）重設嘅目標追蹤
//
//  SwiftUI 冇「邊一個 view 被中鍵撳」嘅事件，但每一列嘅 onHover 會話畀我哋知
//  游標停喺邊個計時器上。StatusMenuController 統一攔截中鍵事件，再嚟呢度攞 ID，
//  唔使再用螢幕座標硬估 —— 之前靠座標嘅做法喺面板入面完全失效。
// ============================================================================

/// 中鍵重設成功之後廣播，畀面板／儀表板顯示可見回應。
extension Notification.Name {
    static let timerDeckMiddleClickReset = Notification.Name("timerDeckMiddleClickReset")
}

final class MiddleClickTracker {
    static let shared = MiddleClickTracker()
    private init() {}

    /// 游標目前停喺邊一個計時器上（只喺主線程讀寫）。
    /// 離開面板 / 計時器被刪除時會自動變 nil，之後退回「重設最快到期嗰個」。
    var hoveredTimerID: String?
}
