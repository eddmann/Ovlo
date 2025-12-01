import UIKit

/// Protocol for haptic feedback to enable testing.
public protocol HapticControllerProtocol: Sendable {
    /// Plays feedback when transitioning between breathing phases
    func playPhaseFeedback() async

    /// Plays feedback when a session completes
    func playCompletionFeedback() async
}

/// iOS implementation of haptic feedback using UIKit.
public struct HapticController: HapticControllerProtocol {
    public init() {}

    @MainActor
    public func playPhaseFeedback() async {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    @MainActor
    public func playCompletionFeedback() async {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

/// Mock haptic controller for testing.
public actor MockHapticController: HapticControllerProtocol {
    public private(set) var phaseFeedbackCount = 0
    public private(set) var completionFeedbackCount = 0

    public init() {}

    public func playPhaseFeedback() async {
        phaseFeedbackCount += 1
    }

    public func playCompletionFeedback() async {
        completionFeedbackCount += 1
    }

    public func reset() {
        phaseFeedbackCount = 0
        completionFeedbackCount = 0
    }
}
