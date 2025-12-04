import AVFoundation

/// Protocol for audio playback to enable testing.
public protocol AudioControllerProtocol: Sendable {
    /// Plays sound when transitioning between breathing phases
    @MainActor func playPhaseTransitionSound() async
    /// Plays a specific chime sound for preview purposes.
    @MainActor func playChime(named chimeName: String) async
}

/// watchOS implementation of audio playback using AVFoundation.
public final class AudioController: AudioControllerProtocol, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?
    private var currentChimeName: String?

    public init() {
        loadChime(named: SettingsManager.shared.selectedChimeName)
    }

    private func loadChime(named chimeName: String) {
        let soundFormats = ["wav", "mp3", "m4a", "caf", "aiff"]

        for format in soundFormats {
            if let url = Bundle.main.url(forResource: chimeName, withExtension: format) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.prepareToPlay()
                    currentChimeName = chimeName
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
        let selectedChime = SettingsManager.shared.selectedChimeName
        if currentChimeName != selectedChime {
            loadChime(named: selectedChime)
        }
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }

    @MainActor
    public func playChime(named chimeName: String) async {
        loadChime(named: chimeName)
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
