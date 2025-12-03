import AVFoundation
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "MusicController")

/// Protocol for background music playback during breathing sessions.
public protocol MusicControllerProtocol: Sendable {
    /// Starts playing the specified track in a loop.
    /// - Parameter trackName: The name of the bundled audio file (without extension)
    @MainActor func startPlayback(trackName: String) async

    /// Stops music playback.
    @MainActor func stopPlayback() async
}

/// iOS implementation of background music playback using AVFoundation.
public final class MusicController: MusicControllerProtocol, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?

    public init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Allow mixing with other audio (chime sounds, other apps)
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            logger.info("Audio session configured for music playback")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func startPlayback(trackName: String) async {
        // Stop any existing playback
        audioPlayer?.stop()
        audioPlayer = nil

        // Try multiple file formats
        let soundFormats = ["wav", "mp3", "m4a", "caf", "aiff"]

        for format in soundFormats {
            if let url = Bundle.main.url(forResource: trackName, withExtension: format) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.numberOfLoops = -1 // Loop indefinitely
                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                    logger.info("Started music playback: \(trackName).\(format)")
                    return
                } catch {
                    logger.error("Failed to load \(trackName).\(format): \(error.localizedDescription)")
                }
            }
        }

        logger.warning("No audio file found for track: \(trackName). Music will not play.")
    }

    @MainActor
    public func stopPlayback() async {
        audioPlayer?.stop()
        audioPlayer = nil
        logger.info("Stopped music playback")
    }
}
