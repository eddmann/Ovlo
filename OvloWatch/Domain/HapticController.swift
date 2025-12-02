import Foundation
#if os(watchOS)
import WatchKit
#endif

/// Protocol for haptic feedback operations to enable testing.
public protocol HapticControllerProtocol: Sendable {
    /// Plays haptic feedback when transitioning between breathing phases
    func playPhaseFeedback() async

    /// Plays haptic feedback when the session completes
    func playCompletionFeedback() async
}

/// Controller for managing haptic feedback on Apple Watch.
///
/// Provides tactile feedback at key moments during the breathing session:
/// - Phase transitions (inhale → exhale)
/// - Session completion
public struct HapticController: HapticControllerProtocol {
    public init() {}

    /// Plays a gentle haptic at the start of each breathing phase.
    @MainActor
    public func playPhaseFeedback() async {
        guard SettingsManager.shared.isHapticEnabled else { return }
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    /// Plays a success haptic when the session completes.
    @MainActor
    public func playCompletionFeedback() async {
        guard SettingsManager.shared.isHapticEnabled else { return }
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
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
