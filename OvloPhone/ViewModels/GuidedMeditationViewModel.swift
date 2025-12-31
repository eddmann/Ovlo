import Foundation
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "GuidedMeditationViewModel")

/// View model for guided meditation sessions.
///
/// Manages audio playback where the session duration is determined
/// by the audio file length rather than a fixed timer.
@MainActor
@Observable
public final class GuidedMeditationViewModel {
    // MARK: - Published State
    private(set) var playbackState: PlaybackState = .ready
    private(set) var elapsedSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var currentMeditationName: String?
    var selectedAudioSourceId: String = SettingsManager.shared.guidedAudioSourceId

    // MARK: - Dependencies
    private let musicController: MusicControllerProtocol
    private let idleTimerController: IdleTimerControllerProtocol
    private let mediaLibraryController: MediaLibraryController

    // MARK: - Private State
    private var sessionStartTime: Date?
    private var currentAudioURL: URL?
    private nonisolated(unsafe) var progressTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new guided meditation view model.
    /// - Parameters:
    ///   - musicController: Controller for audio playback
    ///   - idleTimerController: Controller for preventing screen lock during sessions
    ///   - mediaLibraryController: Controller for accessing Apple Music library
    public init(
        musicController: MusicControllerProtocol = MusicController(),
        idleTimerController: IdleTimerControllerProtocol = IdleTimerController(),
        mediaLibraryController: MediaLibraryController = MediaLibraryController()
    ) {
        self.musicController = musicController
        self.idleTimerController = idleTimerController
        self.mediaLibraryController = mediaLibraryController
    }

    // MARK: - Public API

    /// Starts a guided meditation session with the selected audio.
    public func startSession() async {
        let sourceId = selectedAudioSourceId

        // Try to find the audio source from different sources
        // 1. Check bundled meditations
        if let meditation = BundledAudioSource.meditations.first(where: { $0.id == sourceId }),
           let url = meditation.getURL() {
            await startSession(with: url, name: meditation.displayName)
            return
        }

        // 2. Check imported audio
        if let imported = ImportedAudioStore.shared.find(id: sourceId),
           let url = imported.getURL() {
            await startSession(with: url, name: imported.displayName)
            return
        }

        // 3. Check library audio (starts with "library-")
        if sourceId.hasPrefix("library-") {
            let persistentIDString = String(sourceId.dropFirst("library-".count))
            if let persistentID = UInt64(persistentIDString) {
                let librarySource = LibraryAudioSource(
                    id: sourceId,
                    displayName: "Library Track",
                    artist: nil,
                    duration: nil,
                    persistentID: persistentID
                )
                if let url = mediaLibraryController.getPlaybackURL(for: librarySource) {
                    await startSession(with: url, name: librarySource.displayName)
                    return
                }
            }
        }

        logger.warning("Could not find audio source: \(sourceId)")
    }

    /// Starts a session with a specific audio URL.
    /// - Parameters:
    ///   - url: The URL of the audio file
    ///   - name: Display name for the meditation
    public func startSession(with url: URL, name: String) async {
        currentAudioURL = url
        currentMeditationName = name
        sessionStartTime = Date()
        elapsedSeconds = 0

        // Get duration
        if let duration = await musicController.getDuration(for: url) {
            totalSeconds = Int(duration)
        } else {
            totalSeconds = 0
        }

        idleTimerController.disableIdleTimer()
        playbackState = .playing(progress: 0.0)

        // Start playback with completion callback
        await musicController.playOnce(url: url) { [weak self] in
            Task { @MainActor in
                await self?.handlePlaybackComplete()
            }
        }

        startProgressTracking()
    }

    /// Stops the current session.
    public func stopSession() async {
        progressTask?.cancel()
        progressTask = nil
        await musicController.fadeOutAndStop(duration: 2.0)
        sessionStartTime = nil
        currentAudioURL = nil
        elapsedSeconds = 0
        currentMeditationName = nil
        playbackState = .ready
        idleTimerController.enableIdleTimer()
    }

    /// Returns to the ready state after viewing completion.
    public func dismissCompletion() {
        playbackState = .ready
        elapsedSeconds = 0
        totalSeconds = 0
        sessionStartTime = nil
        currentAudioURL = nil
        currentMeditationName = nil
    }

    // MARK: - Private Implementation

    private func handlePlaybackComplete() async {
        progressTask?.cancel()
        progressTask = nil
        playbackState = .completed
        idleTimerController.enableIdleTimer()
        logger.info("Guided meditation completed")
    }

    private func startProgressTracking() {
        progressTask?.cancel()

        progressTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                let currentTime = await self.musicController.getCurrentTime()
                self.elapsedSeconds = Int(currentTime)

                if self.totalSeconds > 0 {
                    let progress = min(currentTime / Double(self.totalSeconds), 1.0)
                    self.playbackState = .playing(progress: progress)
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    deinit {
        progressTask?.cancel()
    }
}
