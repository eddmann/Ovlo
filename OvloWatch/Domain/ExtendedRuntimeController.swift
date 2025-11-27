import Foundation
import os
#if os(watchOS)
import WatchKit
#endif

private let logger = Logger(subsystem: "com.ovlo.watch", category: "ExtendedRuntime")

/// State of the extended runtime session.
public enum ExtendedRuntimeState: Sendable, Equatable {
    case inactive
    case starting
    case running
    case expiring
    case expired
    case invalid
}

/// Protocol for managing extended runtime sessions to enable background execution.
///
/// This protocol abstracts WKExtendedRuntimeSession to enable dependency injection
/// and testability. Implementations allow breathing sessions to continue running
/// when the watch screen dims.
public protocol ExtendedRuntimeControllerProtocol: Sendable {
    /// Current state of the extended runtime session.
    var state: ExtendedRuntimeState { get async }

    /// Stream of state changes for observation.
    var stateStream: AsyncStream<ExtendedRuntimeState> { get }

    /// Starts an extended runtime session for mindfulness/breathing.
    /// Call when a breathing session begins.
    func startSession() async

    /// Invalidates the extended runtime session.
    /// Call when a breathing session ends or is stopped.
    func invalidateSession() async
}

#if os(watchOS)
/// Production implementation using WKExtendedRuntimeSession.
///
/// Uses the mindfulness session type which is designed for meditation
/// and breathing apps. The system may reclaim execution time after ~30 minutes.
public final class ExtendedRuntimeController: NSObject, ExtendedRuntimeControllerProtocol, @unchecked Sendable {
    private var session: WKExtendedRuntimeSession?
    private var currentState: ExtendedRuntimeState = .inactive
    private let lock = NSLock()

    private let stateContinuation: AsyncStream<ExtendedRuntimeState>.Continuation
    public let stateStream: AsyncStream<ExtendedRuntimeState>

    public override init() {
        var continuation: AsyncStream<ExtendedRuntimeState>.Continuation!
        self.stateStream = AsyncStream { continuation = $0 }
        self.stateContinuation = continuation

        super.init()
    }

    public var state: ExtendedRuntimeState {
        lock.withLock { currentState }
    }

    public func startSession() async {
        await MainActor.run {
            lock.withLock {
                // Invalidate any existing session first
                session?.invalidate()

                let newSession = WKExtendedRuntimeSession()
                newSession.delegate = self
                session = newSession

                updateStateLocked(.starting)
                newSession.start()
                logger.info("Extended runtime session started")
            }
        }
    }

    public func invalidateSession() async {
        await MainActor.run {
            lock.withLock {
                guard let currentSession = session else {
                    logger.debug("No session to invalidate")
                    return
                }

                // Only invalidate if the session is in a running state
                // Avoids "Session not running" errors when session already ended
                if currentSession.state == .running || currentSession.state == .scheduled {
                    currentSession.invalidate()
                    logger.info("Extended runtime session invalidated")
                } else {
                    logger.debug("Session already ended (state: \(String(describing: currentSession.state))), skipping invalidate")
                }

                session = nil
                updateStateLocked(.inactive)
            }
        }
    }

    private func updateStateLocked(_ newState: ExtendedRuntimeState) {
        currentState = newState
        stateContinuation.yield(newState)
    }

    private func updateState(_ newState: ExtendedRuntimeState) {
        lock.withLock {
            updateStateLocked(newState)
        }
    }

    deinit {
        stateContinuation.finish()
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension ExtendedRuntimeController: WKExtendedRuntimeSessionDelegate {
    public func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        updateState(.running)
        logger.info("Extended runtime session is now running")
    }

    public func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        // Session is about to expire (system reclaiming execution time)
        // Typically ~30 seconds warning before expiration
        updateState(.expiring)
        logger.warning("Extended runtime session will expire soon")
    }

    public func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        // Check if this was a normal invalidation (no error) or an unexpected one
        let newState: ExtendedRuntimeState
        if error == nil {
            newState = .inactive
        } else {
            newState = .invalid
        }

        if let error = error {
            logger.error("Extended runtime session invalidated with error: \(error.localizedDescription)")
        } else {
            logger.info("Extended runtime session invalidated with reason: \(String(describing: reason))")
        }

        updateState(newState)
    }
}
#endif

/// Mock extended runtime controller for testing.
///
/// Records all session lifecycle calls and allows tests to simulate
/// various runtime states including expiration scenarios.
public actor MockExtendedRuntimeController: ExtendedRuntimeControllerProtocol {
    // MARK: - Recorded State

    /// Number of times startSession() was called.
    public private(set) var startSessionCallCount = 0

    /// Number of times invalidateSession() was called.
    public private(set) var invalidateSessionCallCount = 0

    /// Whether a session is currently "active" (started but not invalidated).
    public private(set) var isSessionActive = false

    // MARK: - State

    private var currentState: ExtendedRuntimeState = .inactive
    private let stateContinuation: AsyncStream<ExtendedRuntimeState>.Continuation
    public let stateStream: AsyncStream<ExtendedRuntimeState>

    // MARK: - Configuration

    /// When true, startSession() will automatically transition to .running.
    public var autoTransitionToRunning = true

    public init() {
        var continuation: AsyncStream<ExtendedRuntimeState>.Continuation!
        self.stateStream = AsyncStream { continuation = $0 }
        self.stateContinuation = continuation
    }

    // MARK: - ExtendedRuntimeControllerProtocol

    public var state: ExtendedRuntimeState {
        currentState
    }

    public func startSession() async {
        startSessionCallCount += 1
        isSessionActive = true

        updateState(.starting)

        if autoTransitionToRunning {
            updateState(.running)
        }
    }

    public func invalidateSession() async {
        invalidateSessionCallCount += 1
        isSessionActive = false
        updateState(.inactive)
    }

    // MARK: - Test Helpers

    /// Simulates the session expiring (system reclaiming execution time).
    public func simulateExpiring() {
        updateState(.expiring)
    }

    /// Simulates the session fully expired.
    public func simulateExpired() {
        isSessionActive = false
        updateState(.expired)
    }

    /// Simulates an invalid session (e.g., authorization failure).
    public func simulateInvalid() {
        isSessionActive = false
        updateState(.invalid)
    }

    /// Resets all recorded state.
    public func reset() {
        startSessionCallCount = 0
        invalidateSessionCallCount = 0
        isSessionActive = false
        currentState = .inactive
        autoTransitionToRunning = true
    }

    private func updateState(_ newState: ExtendedRuntimeState) {
        currentState = newState
        stateContinuation.yield(newState)
    }
}
