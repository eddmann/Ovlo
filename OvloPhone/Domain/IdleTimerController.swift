import UIKit

/// Protocol for controlling the device's idle timer (screen lock).
/// Allows preventing the device from going to sleep during active sessions.
public protocol IdleTimerControllerProtocol: Sendable {
    @MainActor func disableIdleTimer()
    @MainActor func enableIdleTimer()
}

/// Controls the device's idle timer to prevent screen lock during breathing sessions.
public final class IdleTimerController: IdleTimerControllerProtocol, Sendable {
    public init() {}

    @MainActor
    public func disableIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    @MainActor
    public func enableIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
