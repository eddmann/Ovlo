import Foundation

/// Core breathing session engine that manages state transitions and timing.
///
/// The engine runs on the watch and handles all breathing logic including:
/// - State transitions (inhale → exhale → repeat)
/// - Progress tracking within each phase
/// - Session duration management
/// - State publication via AsyncStream
///
/// This class is designed to be testable by injecting a ClockProtocol.
public actor BreathingEngine {
    // MARK: - Dependencies
    private let clock: ClockProtocol
    private let hapticController: HapticControllerProtocol

    // MARK: - State
    private var currentState: BreathingState = .ready
    private var isRunning = false
    private var runTask: Task<Void, Never>?

    // State stream
    private let stateContinuation: AsyncStream<BreathingState>.Continuation
    public let stateStream: AsyncStream<BreathingState>

    // MARK: - Initialization

    /// Creates a new breathing engine.
    /// - Parameters:
    ///   - clock: Clock for timing operations (injected for testing)
    ///   - hapticController: Controller for haptic feedback
    public init(
        clock: ClockProtocol = ContinuousClock(),
        hapticController: HapticControllerProtocol = HapticController()
    ) {
        self.clock = clock
        self.hapticController = hapticController

        var continuation: AsyncStream<BreathingState>.Continuation!
        self.stateStream = AsyncStream { continuation = $0 }
        self.stateContinuation = continuation
        continuation.yield(.ready)
    }

    // MARK: - Public API

    public func start(session: BreathingSession) async {
        stop()
        isRunning = true
        currentState = .ready

        // Play the first haptic immediately before task scheduling to ensure
        // it fires reliably (fixes race condition on initial breathing phase)
        await hapticController.playPhaseFeedback()

        runTask = Task {
            await runSession(session, isFirstHapticPlayed: true)
        }
    }

    public func stop() {
        isRunning = false
        runTask?.cancel()
        runTask = nil
        updateState(.ready)
    }

    public func getCurrentState() -> BreathingState {
        currentState
    }

    // MARK: - Private Implementation

    private func runSession(_ session: BreathingSession, isFirstHapticPlayed: Bool) async {
        var cyclesCompleted = 0
        let maxCycles = session.totalCycles

        while isRunning && cyclesCompleted < maxCycles {
            // Skip haptic on first inhale if already played in start()
            let skipHaptic = (cyclesCompleted == 0) && isFirstHapticPlayed
            await runInhalePhase(duration: session.inhaleDuration, skipHaptic: skipHaptic)
            guard isRunning else { break }
            await runExhalePhase(duration: session.exhaleDuration)

            cyclesCompleted += 1
        }

        if isRunning {
            updateState(.completed)
            await hapticController.playCompletionFeedback()
            isRunning = false
        }
    }

    private func runInhalePhase(duration: TimeInterval, skipHaptic: Bool = false) async {
        if !skipHaptic {
            await hapticController.playPhaseFeedback()
        }

        let steps = 60
        let stepDuration = duration / Double(steps)

        for step in 0..<steps {
            guard isRunning else { break }

            let progress = Double(step) / Double(steps - 1)
            updateState(.inhaling(progress: progress))

            do {
                try await clock.sleep(for: .seconds(stepDuration))
            } catch {
                break
            }
        }
    }

    private func runExhalePhase(duration: TimeInterval) async {
        await hapticController.playPhaseFeedback()

        let steps = 60
        let stepDuration = duration / Double(steps)

        for step in 0..<steps {
            guard isRunning else { break }

            let progress = Double(step) / Double(steps - 1)
            updateState(.exhaling(progress: progress))

            do {
                try await clock.sleep(for: .seconds(stepDuration))
            } catch {
                break
            }
        }
    }

    private func updateState(_ newState: BreathingState) {
        currentState = newState
        stateContinuation.yield(newState)
    }

    deinit {
        stateContinuation.finish()
    }
}
