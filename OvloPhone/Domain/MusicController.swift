import AVFoundation
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "MusicController")

/// Protocol for background music playback during breathing sessions.
public protocol MusicControllerProtocol: Sendable {
    /// Starts playing the specified track in a loop.
    /// - Parameter trackName: The name of the bundled audio file (without extension)
    @MainActor func startPlayback(trackName: String) async

    /// Starts playing audio from URL in a loop.
    /// - Parameter url: The URL of the audio file to play
    @MainActor func startPlayback(url: URL) async

    /// Starts playing audio once (no loop) and calls completion when finished.
    /// - Parameters:
    ///   - url: The URL of the audio file to play
    ///   - onComplete: Called when playback finishes naturally
    @MainActor func playOnce(url: URL, onComplete: @escaping @Sendable () -> Void) async

    /// Gets the duration of an audio file at the given URL.
    /// - Parameter url: The URL of the audio file
    /// - Returns: The duration in seconds, or nil if unavailable
    @MainActor func getDuration(for url: URL) async -> TimeInterval?

    /// Gets the current playback time.
    /// - Returns: The current time in seconds
    @MainActor func getCurrentTime() async -> TimeInterval

    /// Stops music playback immediately.
    @MainActor func stopPlayback() async

    /// Fades out the music over the specified duration, then stops playback.
    /// - Parameter duration: The fade duration in seconds (default: 10.0)
    @MainActor func fadeOutAndStop(duration: TimeInterval) async
}

/// iOS implementation of background music playback using AVFoundation.
public final class MusicController: NSObject, MusicControllerProtocol, AVAudioPlayerDelegate, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?
    private var onPlaybackComplete: (@Sendable () -> Void)?

    public override init() {
        super.init()
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
    public func startPlayback(url: URL) async {
        // Stop any existing playback
        audioPlayer?.stop()
        audioPlayer = nil
        onPlaybackComplete = nil

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            logger.info("Started music playback from URL: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to play audio from URL: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func stopPlayback() async {
        audioPlayer?.stop()
        audioPlayer = nil
        logger.info("Stopped music playback")
    }

    @MainActor
    public func fadeOutAndStop(duration: TimeInterval = 10.0) async {
        guard let player = audioPlayer else { return }

        // Detach so fade completes even if calling task is cancelled
        Task.detached { @MainActor in
            player.setVolume(0.0, fadeDuration: duration)
            try? await Task.sleep(for: .seconds(duration))
            player.stop()
        }

        audioPlayer = nil
        onPlaybackComplete = nil
        logger.info("Started fade out for music playback")
    }

    @MainActor
    public func playOnce(url: URL, onComplete: @escaping @Sendable () -> Void) async {
        // Stop any existing playback
        audioPlayer?.stop()
        audioPlayer = nil
        onPlaybackComplete = nil

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0 // Play once
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            onPlaybackComplete = onComplete
            audioPlayer?.play()
            logger.info("Started single playback: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to play audio: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func getDuration(for url: URL) async -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            logger.error("Failed to get duration for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    public func getCurrentTime() async -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }

    // MARK: - AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            logger.info("Audio playback completed successfully")
            onPlaybackComplete?()
        }
        onPlaybackComplete = nil
    }
}
