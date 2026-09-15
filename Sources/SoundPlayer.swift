import Foundation
import AVFoundation

// ============================================================================
//  Timer Deck — 铃声
//  直接播 App bundle 内的 wav，沿用浏览器版的四个音档
// ============================================================================

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var cache: [String: AVAudioPlayer] = [:]

    private init() {}

    func play(_ name: String) {
        guard !name.isEmpty, name != "none" else { return }
        guard let player = player(for: name) else { return }
        player.currentTime = 0
        player.play()
    }

    func stop() {
        for p in cache.values { p.stop() }
    }

    /// 试听（设定页用）
    func preview(_ name: String) {
        play(name)
    }

    private func player(for name: String) -> AVAudioPlayer? {
        if let cached = cache[name] { return cached }
        let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "sounds")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Resources/sounds")
        guard let u = url, let p = try? AVAudioPlayer(contentsOf: u) else {
            NSLog("[TimerDeck] 找不到音档: \(name).wav")
            return nil
        }
        p.prepareToPlay()
        cache[name] = p
        return p
    }
}
