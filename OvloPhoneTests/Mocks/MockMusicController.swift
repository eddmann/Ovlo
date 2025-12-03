import Foundation
@testable import OvloPhone

/// Mock music controller for testing.
/// Records calls without playing actual music.
public actor MockMusicController: MusicControllerProtocol {
    public private(set) var startPlaybackCount = 0
    public private(set) var stopPlaybackCount = 0
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

    /// Resets all recorded state.
    public func reset() {
        startPlaybackCount = 0
        stopPlaybackCount = 0
        lastPlayedTrack = nil
    }
}
