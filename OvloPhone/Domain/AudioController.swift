import AVFoundation
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "AudioController")

/// Protocol for audio playback to enable testing.
public protocol AudioControllerProtocol: Sendable {
    /// Plays the phase transition sound if enabled in settings.
    @MainActor func playPhaseTransitionSound() async
}

/// iOS implementation of audio playback using AVFoundation.
public final class AudioController: AudioControllerProtocol, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?

    public init() {
        prepareAudio()
    }

    private func prepareAudio() {
        // Try multiple file formats
        let soundFormats = ["wav", "mp3", "m4a", "caf", "aiff"]

        for format in soundFormats {
            if let url = Bundle.main.url(forResource: "chime", withExtension: format) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.prepareToPlay()
                    logger.info("Loaded chime sound: chime.\(format)")
                    return
                } catch {
                    logger.error("Failed to load chime.\(format): \(error.localizedDescription)")
                }
            }
        }

        logger.warning("No chime sound file found in bundle. Sound will not play.")
    }

    @MainActor
    public func playPhaseTransitionSound() async {
        guard SettingsManager.shared.isSoundEnabled else { return }
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
