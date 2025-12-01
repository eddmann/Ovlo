import Foundation
@testable import OvloPhone

/// Test clock that allows manual control over time progression.
///
/// This clock suspends on sleep() until advance() is called, giving tests
/// full control over timing. Tests can step through engine states precisely.
public actor TestClock: ClockProtocol {
    /// Records all sleep durations that were requested
    private(set) var sleepDurations: [Duration] = []

    /// Total time that has been "slept"
    private(set) var totalSleptTime: Duration = .zero

    /// Whether to throw an error on sleep (simulates cancellation)
    public var shouldThrowOnSleep = false

    /// Pending continuations waiting for advance()
    private var sleepContinuations: [CheckedContinuation<Void, Error>] = []

    public init() {}

    /// Suspends until advance() is called.
    /// - Parameter duration: The requested sleep duration (recorded for verification)
    public func sleep(for duration: Duration) async throws {
        if shouldThrowOnSleep {
            throw CancellationError()
        }

        sleepDurations.append(duration)
        totalSleptTime = totalSleptTime + duration

        // Suspend until advance() is called
        try await withCheckedThrowingContinuation { continuation in
            sleepContinuations.append(continuation)
        }
    }

    /// Advances time by resuming one pending sleep call.
    /// Call this to let the engine proceed one step.
    public func advance() {
        guard !sleepContinuations.isEmpty else { return }
        let continuation = sleepContinuations.removeFirst()
        continuation.resume()
    }

    /// Advances time by resuming multiple pending sleep calls.
    /// - Parameter count: Number of sleep calls to resume
    public func advance(steps count: Int) {
        for _ in 0..<count {
            advance()
        }
    }

    /// Advances time by resuming all pending sleep calls.
    public func advanceAll() {
        let continuations = sleepContinuations
        sleepContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    /// Number of pending sleep calls waiting for advance()
    public var pendingSleepCount: Int {
        sleepContinuations.count
    }

    /// Resets all recorded state
    public func reset() {
        sleepDurations.removeAll()
        totalSleptTime = .zero
        shouldThrowOnSleep = false
        // Cancel any pending sleeps
        for continuation in sleepContinuations {
            continuation.resume(throwing: CancellationError())
        }
        sleepContinuations.removeAll()
    }

    /// Returns the total number of sleep calls made
    public func sleepCallCount() -> Int {
        sleepDurations.count
    }
}

// Duration addition helper
extension Duration {
    static func + (lhs: Duration, rhs: Duration) -> Duration {
        let lhsComponents = lhs.components
        let rhsComponents = rhs.components
        let totalSeconds = lhsComponents.seconds + rhsComponents.seconds
        let totalAtto = lhsComponents.attoseconds + rhsComponents.attoseconds

        return Duration(secondsComponent: totalSeconds, attosecondsComponent: totalAtto)
    }

    static var zero: Duration {
        .seconds(0)
    }
}
