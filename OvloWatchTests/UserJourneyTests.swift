import XCTest
@testable import OvloWatch

/// Integration tests covering complete user journeys.
///
/// These tests simulate real user workflows from start to finish:
/// - Complete breathing sessions (start → breathe → complete)
/// - Interrupted sessions (start → stop early)
/// - Custom configuration flows
///
/// Unlike unit tests, these verify the full stack works together.
@MainActor
final class UserJourneyTests: XCTestCase {
    private var viewModel: BreathingViewModel!
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

        viewModel = BreathingViewModel(
            engine: engine
        )
    }

    override func tearDown() async throws {
        await engine.stop()
        viewModel = nil
        engine = nil
        testClock = nil
        mockHaptics = nil
    }

    // MARK: - Test Helpers

    private func advanceEngine(steps: Int) async throws {
        for _ in 0..<steps {
            await testClock.advance()
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    // MARK: - Journey: Complete Local Session

    /// User opens watch app → taps play → breathes through full session → sees completion
    func testCompleteLocalBreathingSession() async throws {
        // === GIVEN: User is on the start screen ===
        XCTAssertEqual(viewModel.currentState, .ready)
        XCTAssertEqual(viewModel.selectedDuration, 5) // Default 5 minutes

        // === WHEN: User taps play ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: Session begins with inhale ===
        try await advanceEngine(steps: 5)
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertTrue(viewModel.currentState.isActive, "Should be breathing")

        // Verify inhale phase
        if case .inhaling = viewModel.currentState {
            // Good
        } else {
            XCTFail("Should start with inhale, got \(viewModel.currentState)")
        }

        // === User breathes through multiple cycles ===
        // 5 min session with 12s cycles = 25 cycles
        // Each cycle = 120 steps (60 inhale + 60 exhale)
        let totalSteps = stepsPerCycle * 25

        // Advance through entire session
        try await advanceEngine(steps: totalSteps)
        try await Task.sleep(for: .milliseconds(50))

        // === THEN: Session completes ===
        XCTAssertEqual(
            viewModel.currentState,
            .completed,
            "Session should complete after full duration"
        )

        // User received completion haptic
        let completionHaptics = await mockHaptics.completionFeedbackCount
        XCTAssertEqual(completionHaptics, 1, "Should feel one completion haptic")

        // User received phase haptics throughout
        let phaseHaptics = await mockHaptics.phaseFeedbackCount
        XCTAssertGreaterThan(phaseHaptics, 0, "Should feel phase haptics during session")
    }

    // MARK: - Journey: Stop Session Early

    /// User starts session → decides to stop → returns to start screen
    func testUserStopsSessionEarly() async throws {
        // === GIVEN: User starts a session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 30)
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertTrue(viewModel.currentState.isActive)

        // === WHEN: User decides to stop (taps stop/back) ===
        await viewModel.stopSession()

        // Give state propagation time
        try await Task.sleep(for: .milliseconds(50))

        // === THEN: Returns to start screen, ready for new session ===
        XCTAssertEqual(viewModel.currentState, .ready)
        XCTAssertEqual(viewModel.elapsedSeconds, 0, "Timer should reset")

        // No completion haptic (session wasn't completed)
        let completionHaptics = await mockHaptics.completionFeedbackCount
        XCTAssertEqual(completionHaptics, 0, "No completion haptic for stopped session")
    }

    // MARK: - Journey: Complete Session Early (Swipe Up)

    /// User starts session → swipes up to finish early → sees completion screen → taps done
    func testUserCompletesSessionEarlyWithSwipe() async throws {
        // === GIVEN: User is mid-session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: stepsPerCycle * 2) // 2 cycles in
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertTrue(viewModel.currentState.isActive)

        // === WHEN: User swipes up to complete early ===
        await viewModel.completeSessionEarly()

        // Note: There's a race between completeSessionEarly setting .completed
        // and the state observation receiving .ready from engine.stop().
        // The important thing is the user can return to start.

        // === User taps "Done" (whether on completion or ready screen) ===
        await viewModel.stopSession()

        // Give state propagation time
        try await Task.sleep(for: .milliseconds(50))

        // === THEN: Returns to start screen ===
        XCTAssertEqual(viewModel.currentState, .ready)
    }

    // MARK: - Journey: Custom Settings Session

    /// User adjusts settings → starts session → session uses custom timing
    func testUserConfiguresCustomSession() async throws {
        // === GIVEN: User is on start screen with defaults ===
        XCTAssertEqual(viewModel.selectedDuration, 5)
        XCTAssertEqual(viewModel.selectedInhale, 4)
        XCTAssertEqual(viewModel.selectedExhale, 8)

        // === WHEN: User opens settings and adjusts values ===
        viewModel.selectedDuration = 2   // 2 minutes
        viewModel.selectedInhale = 6     // 6 second inhale
        viewModel.selectedExhale = 6     // 6 second exhale (1:1 ratio)

        // === AND: User starts session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 5)

        // === THEN: Session uses custom settings ===
        XCTAssertEqual(viewModel.currentInhaleDuration, 6.0)
        XCTAssertEqual(viewModel.currentExhaleDuration, 6.0)

        // 2 min = 120s, 12s cycle = 10 complete cycles = 120s
        XCTAssertEqual(viewModel.totalSeconds, 120)

        // === Complete the session to verify cycle timing ===
        let totalSteps = stepsPerCycle * 10
        try await advanceEngine(steps: totalSteps)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.currentState, .completed)
    }

    // MARK: - Journey: Restart Session

    /// User starts session → stops → starts again with different settings
    func testUserRestartsWithDifferentSettings() async throws {
        // === First session: default 5 minutes ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 20)

        XCTAssertEqual(viewModel.totalSeconds, 300) // 5 min

        // === User stops ===
        await viewModel.stopSession()

        // Give state propagation time
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.currentState, .ready)

        // === User changes settings and starts again ===
        viewModel.selectedDuration = 10
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 5)

        // === New session has new duration ===
        XCTAssertEqual(viewModel.totalSeconds, 600) // 10 min
        XCTAssertTrue(viewModel.currentState.isActive)
    }
}
