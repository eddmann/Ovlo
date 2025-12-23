import Foundation
@testable import OvloPhone

/// Mock music controller for testing.
/// Records calls without playing actual music.
public actor MockMusicController: MusicControllerProtocol {
    public private(set) var startPlaybackCount = 0
    public private(set) var stopPlaybackCount = 0
    public private(set) var fadeOutAndStopCount = 0
    public private(set) var lastFadeOutDuration: TimeInterval?
    public private(set) var lastPlayedTrack: String?

    public init() {}

    @MainActor
    public func startPlayback(trackName: String) async {
        await recordStart(trackName: trackName)
    }

    private func recordStart(trackName: String) {
        startPlaybackCount += 1
        lastPlayedTrack = trackName
    }

    @MainActor
    public func stopPlayback() async {
        await recordStop()
    }

    private func recordStop() {
        stopPlaybackCount += 1
    }

    @MainActor
    public func fadeOutAndStop(duration: TimeInterval) async {
        await recordFadeOut(duration: duration)
    }

    private func recordFadeOut(duration: TimeInterval) {
        fadeOutAndStopCount += 1
        lastFadeOutDuration = duration
    }

    /// Resets all recorded state.
    public func reset() {
        startPlaybackCount = 0
        stopPlaybackCount = 0
        fadeOutAndStopCount = 0
        lastFadeOutDuration = nil
        lastPlayedTrack = nil
    }
}
