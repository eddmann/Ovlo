import AVFoundation

/// Protocol for audio playback to enable testing.
public protocol AudioControllerProtocol: Sendable {
    /// Plays sound when transitioning between breathing phases
    @MainActor func playPhaseTransitionSound() async
}

/// watchOS implementation of audio playback using AVFoundation.
public final class AudioController: AudioControllerProtocol, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?

    public init() {
        prepareAudio()
    }

    private func prepareAudio() {
        let soundFormats = ["wav", "mp3", "m4a", "caf", "aiff"]

        for format in soundFormats {
            if let url = Bundle.main.url(forResource: "chime", withExtension: format) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.prepareToPlay()
                    return
                } catch {
                    // Try next format
                }
            }
        }
    }

    @MainActor
    public func playPhaseTransitionSound() async {
        guard SettingsManager.shared.isSoundEnabled else { return }
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
