import Foundation
@testable import OvloPhone

/// Mock audio controller for testing.
/// Records calls without playing actual audio.
public actor MockAudioController: AudioControllerProtocol {
    public private(set) var playCount = 0

    public init() {}

    @MainActor
    public func playPhaseTransitionSound() async {
        await incrementPlayCount()
    }

    private func incrementPlayCount() {
        playCount += 1
    }

    /// Resets all recorded state.
    public func reset() {
        playCount = 0
    }
}
