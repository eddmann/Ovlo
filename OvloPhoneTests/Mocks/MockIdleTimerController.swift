import Foundation
@testable import OvloPhone

/// Mock idle timer controller for testing.
/// Records calls to enable/disable without affecting the actual device.
public final class MockIdleTimerController: IdleTimerControllerProtocol, @unchecked Sendable {
    public private(set) var disableCallCount = 0
    public private(set) var enableCallCount = 0
    public private(set) var isIdleTimerDisabled = false

    public init() {}

    @MainActor
    public func disableIdleTimer() {
        disableCallCount += 1
        isIdleTimerDisabled = true
    }

    @MainActor
    public func enableIdleTimer() {
        enableCallCount += 1
        isIdleTimerDisabled = false
    }

    /// Resets all recorded state
    public func reset() {
        disableCallCount = 0
        enableCallCount = 0
        isIdleTimerDisabled = false
    }
}
