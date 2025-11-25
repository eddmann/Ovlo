import Foundation

/// Protocol for abstracting time-based operations to enable testing.
///
/// This protocol wraps Swift's Clock API to allow injection of test clocks
/// that can control time progression during testing.
public protocol ClockProtocol: Sendable {
    /// Sleeps for the specified duration
    /// - Parameter duration: The duration to sleep
    func sleep(for duration: Duration) async throws
}

/// Production implementation using Swift's continuous clock
public struct ContinuousClock: ClockProtocol {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

/// Extension to make Duration construction more ergonomic
extension Duration {
    /// Creates a duration from seconds
    /// - Parameter seconds: Number of seconds
    /// - Returns: A Duration representing the specified seconds
    public static func seconds(_ seconds: Double) -> Duration {
        .milliseconds(Int(seconds * 1000))
    }
}
