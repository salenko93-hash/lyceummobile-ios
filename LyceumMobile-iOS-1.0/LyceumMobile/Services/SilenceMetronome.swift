import Foundation
import AVFoundation

@MainActor
final class SilenceMetronome {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var isPlaying = false

    init() {
        guard let file = Bundle.main.url(forResource: "metronome_tick", withExtension: "wav") else {
            return
        }
        do {
            // Respects mute switch and does not interrupt official alarm apps.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            player = try AVAudioPlayer(contentsOf: file)
            player?.prepareToPlay()
        } catch {
            player = nil // Silence display remains functional if audio fails.
        }
    }

    func setActive(_ active: Bool, volume: Double, canContinue: @escaping () -> Bool) {
        guard active, volume > 0, player != nil else {
            stop()
            return
        }
        player?.volume = Float(min(1, max(0, volume)))
        if isPlaying { return }

        isPlaying = true
        beat(canContinue: canContinue)
        let clock = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            // Main run loop timer: at most one beat per second, never catch-up bursts.
            Task { @MainActor in
                self?.beat(canContinue: canContinue)
            }
        }
        clock.tolerance = 0.02
        timer = clock
        RunLoop.main.add(clock, forMode: .common)
    }

    private func beat(canContinue: () -> Bool) {
        guard isPlaying, canContinue() else { stop(); return }
        player?.stop()
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        isPlaying = false
    }
}
