import Foundation
@testable import OvloPhone

/// Mock audio controller for testing.
/// Records calls without playing actual audio.
public actor MockAudioController: AudioControllerProtocol {
    public private(set) var playCount = 0
    public private(set) var lastPlayedChime: String?

    public init() {}

    @MainActor
    public func playPhaseTransitionSound() async {
        await incrementPlayCount()
    }

    @MainActor
    public func playChime(named chimeName: String) async {
        await recordChimePlay(chimeName)
    }

    private func incrementPlayCount() {
        playCount += 1
    }

    private func recordChimePlay(_ chimeName: String) {
        playCount += 1
        lastPlayedChime = chimeName
    }

    /// Resets all recorded state.
    public func reset() {
        playCount = 0
        lastPlayedChime = nil
    }
}
