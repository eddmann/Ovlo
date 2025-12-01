import XCTest
@testable import OvloPhone

/// Tests for the BreathingEngine - the core breathing session logic.
///
/// These tests validate user-facing behaviors:
/// - Starting a session begins the breathing animation
/// - Breathing cycles smoothly between inhale and exhale
/// - Sessions complete after the configured duration
/// - Users can stop sessions at any time
/// - Haptic feedback provides tactile guidance
@MainActor
final class BreathingEngineTests: XCTestCase {
    private var engine: BreathingEngine!
    private var testClock: TestClock!
    private var mockHaptics: MockHapticController!

    // MARK: - Constants

    private let stepsPerPhase = 60
    private var stepsPerCycle: Int { stepsPerPhase * 2 }

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        testClock = TestClock()
        mockHaptics = MockHapticController()
        engine = BreathingEngine(
            clock: testClock,
            hapticController: mockHaptics
        )
    }

    override func tearDown() async throws {
        await engine.stop()
        engine = nil
        testClock = nil
        mockHaptics = nil
    }

    // MARK: - Test Helpers

    /// Advances the test clock by a specified number of steps, allowing the engine to progress.
    private func advanceEngine(steps: Int) async throws {
        for _ in 0..<steps {
            await testClock.advance()
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    /// Starts the engine and waits for it to begin processing.
    private func startEngine(durationSeconds: Int = 60) async throws {
        let session = BreathingSession(durationSeconds: durationSeconds)
        await engine.start(session: session)
        try await Task.sleep(for: .milliseconds(10))
    }

    // MARK: - Session Lifecycle Tests

    func testEngineStartsInReadyState() async {
        let state = await engine.getCurrentState()
        XCTAssertEqual(state, .ready, "Engine should start in ready state")
    }

    func testStartingSessionBeginsInhaling() async throws {
        let initialState = await engine.getCurrentState()
        XCTAssertEqual(initialState, .ready)

        try await startEngine()
        try await advanceEngine(steps: 3)
        try await Task.sleep(for: .milliseconds(10))

        let state = await engine.getCurrentState()

        if case .inhaling(let progress) = state {
            XCTAssertGreaterThanOrEqual(progress, 0.0)
            XCTAssertLessThanOrEqual(progress, 1.0)
        } else {
            XCTFail("Expected inhaling state after starting session, got \(state)")
        }
    }

    func testBreathingCyclesFromInhaleToExhale() async throws {
        try await startEngine()

        // Complete the inhale phase (60 steps)
        try await advanceEngine(steps: stepsPerPhase)
        try await Task.sleep(for: .milliseconds(10))

        let state = await engine.getCurrentState()

        if case .exhaling = state {
            // Success - transitioned to exhale after inhale completed
        } else {
            XCTFail("Expected exhaling state after inhale completes, got \(state)")
        }
    }

    func testBreathingAnimationShowsProgress() async throws {
        try await startEngine()

        // Advance partway through inhale
        try await advanceEngine(steps: 10)
        try await Task.sleep(for: .milliseconds(10))

        let earlyState = await engine.getCurrentState()

        // Advance further
        try await advanceEngine(steps: 20)
        try await Task.sleep(for: .milliseconds(10))

        let laterState = await engine.getCurrentState()

        // Verify progress increased
        if case .inhaling(let earlyProgress) = earlyState,
           case .inhaling(let laterProgress) = laterState {
            XCTAssertGreaterThan(
                laterProgress,
                earlyProgress,
                "Progress should increase as breathing animation advances"
            )
        } else {
            XCTFail("Expected both states to be inhaling, got \(earlyState) and \(laterState)")
        }
    }

    // MARK: - Session Completion Tests

    func testSessionCompletesAfterFullDuration() async throws {
        // 60-second session with 12s cycles (4s inhale + 8s exhale) = 5 cycles
        let completionExpectation = expectation(description: "Session completes")

        let observeTask = Task {
            for await state in await self.engine.stateStream {
                if state == .completed {
                    completionExpectation.fulfill()
                    break
                }
            }
        }

        try await startEngine(durationSeconds: 60)

        // Advance through all 5 cycles
        try await advanceEngine(steps: stepsPerCycle * 5)

        await fulfillment(of: [completionExpectation], timeout: 3.0)
        observeTask.cancel()

        let finalState = await engine.getCurrentState()
        XCTAssertEqual(finalState, .completed, "Session should complete after full duration")
    }

    func testUserFeelsCompletionHaptic() async throws {
        try await startEngine(durationSeconds: 60)

        // Complete the session
        try await advanceEngine(steps: stepsPerCycle * 5)
        try await Task.sleep(for: .milliseconds(50))

        let completionCount = await mockHaptics.completionFeedbackCount
        XCTAssertEqual(
            completionCount,
            1,
            "Exactly one completion haptic should play when session ends"
        )
    }

    // MARK: - Stop Behavior Tests

    func testUserCanStopSessionAnytime() async throws {
        try await startEngine()

        // Advance into inhale phase
        try await advanceEngine(steps: 10)

        // Verify we're in an active state
        let activeState = await engine.getCurrentState()
        XCTAssertTrue(activeState.isActive, "Should be actively breathing before stop")

        await engine.stop()

        let stoppedState = await engine.getCurrentState()
        XCTAssertEqual(stoppedState, .ready, "Stopping should return to ready state")
    }

    func testStopCleansUpDuringAnyPhase() async throws {
        // Test stopping during exhale phase specifically
        try await startEngine()

        // Advance through inhale (60 steps) and into exhale (10 more steps)
        try await advanceEngine(steps: stepsPerPhase + 10)

        let midExhaleState = await engine.getCurrentState()
        if case .exhaling = midExhaleState {
            // Confirmed we're in exhale phase
        } else {
            XCTFail("Expected to be in exhale phase, got \(midExhaleState)")
        }

        await engine.stop()

        let stoppedState = await engine.getCurrentState()
        XCTAssertEqual(stoppedState, .ready, "Stop should work cleanly during exhale")
    }

    // MARK: - Haptic Feedback Tests

    func testUserFeelsHapticAtEachPhaseTransition() async throws {
        try await startEngine()

        // Complete one full cycle (inhale + exhale)
        try await advanceEngine(steps: stepsPerCycle)
        try await Task.sleep(for: .milliseconds(10))

        let phaseCount = await mockHaptics.phaseFeedbackCount

        // Should have haptics at: start of inhale, start of exhale, start of next inhale = 3
        XCTAssertEqual(
            phaseCount,
            3,
            "Should play haptic at start of each phase (inhale, exhale, next inhale)"
        )
    }

    func testNoHapticsAfterStop() async throws {
        try await startEngine()
        try await advanceEngine(steps: 5)

        let countBeforeStop = await mockHaptics.phaseFeedbackCount

        await engine.stop()
        await mockHaptics.reset()

        // Try to advance after stop (should not produce haptics)
        try await advanceEngine(steps: 10)

        let countAfterStop = await mockHaptics.phaseFeedbackCount
        XCTAssertEqual(
            countAfterStop,
            0,
            "No haptics should play after session is stopped"
        )
    }
}
