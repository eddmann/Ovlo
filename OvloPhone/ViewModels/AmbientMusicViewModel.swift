import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.ovlo.phone", category: "AmbientMusicViewModel")

/// View model for ambient music sessions.
///
/// Manages timed music playback sessions where users listen to
/// continuous music for a selected duration.
@MainActor
@Observable
public final class AmbientMusicViewModel {
    // MARK: - Published State
    private(set) var playbackState: PlaybackState = .ready
    private(set) var elapsedSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var currentTrackName: String?
    private(set) var currentAffirmation: String?
    var selectedDuration: Int = SettingsManager.shared.ambientDuration
    var selectedAudioSourceId: String = SettingsManager.shared.ambientAudioSourceId

    // MARK: - Dependencies
    private let musicController: MusicControllerProtocol
    private let idleTimerController: IdleTimerControllerProtocol
    private let mediaLibraryController: MediaLibraryController

    // MARK: - Private State
    private var sessionStartTime: Date?
    private var lastAffirmationTime: Date?
    private let affirmationInterval: TimeInterval = 30 // seconds between affirmation changes
    private nonisolated(unsafe) var progressTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new ambient music view model.
    /// - Parameters:
    ///   - musicController: Controller for music playback
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

    /// Starts an ambient music session with the current settings.
    public func startSession() async {
        totalSeconds = selectedDuration * 60
        elapsedSeconds = 0
        sessionStartTime = Date()

        // Try different audio sources
        // 1. Check bundled tracks
        if let track = BundledAudioSource.musicTracks.first(where: { $0.id == selectedAudioSourceId }) {
            currentTrackName = track.displayName
            await musicController.startPlayback(trackName: track.fileName)
        }
        // 2. Check imported audio
        else if let imported = ImportedAudioStore.shared.find(id: selectedAudioSourceId),
                let url = imported.getURL() {
            currentTrackName = imported.displayName
            await musicController.startPlayback(url: url)
        }
        // 3. Check library audio (starts with "library-")
        else if selectedAudioSourceId.hasPrefix("library-") {
            let persistentIDString = String(selectedAudioSourceId.dropFirst("library-".count))
            if let persistentID = UInt64(persistentIDString) {
                let librarySource = LibraryAudioSource(
                    id: selectedAudioSourceId,
                    displayName: "Library Track",
                    artist: nil,
                    duration: nil,
                    persistentID: persistentID
                )
                if let url = mediaLibraryController.getPlaybackURL(for: librarySource) {
                    currentTrackName = librarySource.displayName
                    await musicController.startPlayback(url: url)
                }
            }
        }
        // Fallback to track name
        else {
            currentTrackName = selectedAudioSourceId
            await musicController.startPlayback(trackName: selectedAudioSourceId)
        }

        // Initialize affirmation if enabled
        if SettingsManager.shared.isAmbientAffirmationsEnabled {
            AffirmationManager.shared.shuffle()
            withAnimation(.easeInOut(duration: 0.5)) {
                currentAffirmation = AffirmationManager.shared.nextAffirmation()
            }
            lastAffirmationTime = Date()
        } else {
            currentAffirmation = nil
        }

        idleTimerController.disableIdleTimer()
        playbackState = .playing(progress: 0.0)
        startProgressTracking()
    }

    /// Stops the current session with a fade out.
    public func stopSession() async {
        progressTask?.cancel()
        progressTask = nil
        await musicController.fadeOutAndStop(duration: 2.0)
        sessionStartTime = nil
        elapsedSeconds = 0
        currentTrackName = nil
        currentAffirmation = nil
        lastAffirmationTime = nil
        playbackState = .ready
        idleTimerController.enableIdleTimer()
    }

    /// Returns to the ready state after viewing completion.
    public func dismissCompletion() {
        playbackState = .ready
        elapsedSeconds = 0
        sessionStartTime = nil
        currentTrackName = nil
        currentAffirmation = nil
        lastAffirmationTime = nil
    }

    // MARK: - Private Implementation

    private func startProgressTracking() {
        progressTask?.cancel()

        progressTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                guard let startTime = self.sessionStartTime else { break }

                let elapsed = Int(Date().timeIntervalSince(startTime))
                self.elapsedSeconds = elapsed

                let progress = min(Double(elapsed) / Double(self.totalSeconds), 1.0)
                self.playbackState = .playing(progress: progress)

                // Update affirmation if interval has passed
                self.updateAffirmationIfNeeded()

                // Check if session is complete
                if elapsed >= self.totalSeconds {
                    await self.completeSession()
                    break
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func updateAffirmationIfNeeded() {
        guard SettingsManager.shared.isAmbientAffirmationsEnabled,
              let lastTime = lastAffirmationTime else { return }

        if Date().timeIntervalSince(lastTime) >= affirmationInterval {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentAffirmation = AffirmationManager.shared.nextAffirmation()
            }
            lastAffirmationTime = Date()
        }
    }

    private func completeSession() async {
        progressTask?.cancel()
        progressTask = nil
        await musicController.fadeOutAndStop(duration: 2.0)
        playbackState = .completed
        idleTimerController.enableIdleTimer()
    }

    deinit {
        progressTask?.cancel()
    }
}
