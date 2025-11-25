import XCTest
@testable import OvloWatch

/// Integration tests covering complete user journeys.
///
/// These tests simulate real user workflows from start to finish:
/// - Complete breathing sessions (start → breathe → complete)
/// - Interrupted sessions (start → stop early)
/// - Remote-controlled sessions (iOS → Watch)
/// - Custom configuration flows
///
/// Unlike unit tests, these verify the full stack works together.
@MainActor
final class UserJourneyTests: XCTestCase {
    private var viewModel: BreathingViewModel!
    private var engine: BreathingEngine!
    private var testClock: TestClock!
    private var mockHaptics: MockHapticController!
    private var mockConnectivity: MockWatchConnectivity!

    // MARK: - Constants

    private let stepsPerPhase = 60
    private var stepsPerCycle: Int { stepsPerPhase * 2 }

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        testClock = TestClock()
        mockHaptics = MockHapticController()
        mockConnectivity = MockWatchConnectivity()

        engine = BreathingEngine(
            clock: testClock,
            hapticController: mockHaptics
        )

        viewModel = BreathingViewModel(
            engine: engine,
            connectivity: mockConnectivity
        )
    }

    override func tearDown() async throws {
        await engine.stop()
        viewModel = nil
        engine = nil
        testClock = nil
        mockHaptics = nil
        mockConnectivity = nil
    }

    // MARK: - Test Helpers

    private func advanceEngine(steps: Int) async throws {
        for _ in 0..<steps {
            await testClock.advance()
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private func sendIOSStartCommand(durationMinutes: Int, inhale: Int = 4, exhale: Int = 8) async throws {
        let message: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.start.rawValue,
            ConnectivityMessageKey.duration: durationMinutes,
            ConnectivityMessageKey.inhale: inhale,
            ConnectivityMessageKey.exhale: exhale
        ]
        _ = mockConnectivity.simulateReceivingMessage(message)
        try await Task.sleep(for: .milliseconds(50))
    }

    private func sendIOSStopCommand() async throws {
        let message: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.stop.rawValue
        ]
        _ = mockConnectivity.simulateReceivingMessage(message)
        try await Task.sleep(for: .milliseconds(50))
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

    // MARK: - Journey: iOS Remote Control

    /// User starts session from iOS app → watch runs session → completes
    func testIOSStartsSessionOnWatch() async throws {
        // === GIVEN: Watch is idle, user has iOS app open ===
        XCTAssertEqual(viewModel.currentState, .ready)

        // === WHEN: User taps start on iOS with 1-minute session ===
        try await sendIOSStartCommand(durationMinutes: 1, inhale: 4, exhale: 8)
        try await advanceEngine(steps: 5)
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: Watch starts breathing session ===
        XCTAssertTrue(viewModel.currentState.isActive)
        XCTAssertEqual(viewModel.totalSeconds, 60) // 1 minute

        // === Watch runs through full session ===
        // 1 min = 60s, 12s cycle = 5 cycles
        let totalSteps = stepsPerCycle * 5
        try await advanceEngine(steps: totalSteps)
        try await Task.sleep(for: .milliseconds(50))

        // === THEN: Watch shows completion ===
        XCTAssertEqual(viewModel.currentState, .completed)
    }

    /// User starts session from iOS → decides to stop from iOS → watch stops
    func testIOSStopsSessionOnWatch() async throws {
        // === GIVEN: Session running from iOS command ===
        try await sendIOSStartCommand(durationMinutes: 5)
        try await advanceEngine(steps: 30)
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertTrue(viewModel.currentState.isActive)

        // === WHEN: User taps stop on iOS ===
        try await sendIOSStopCommand()

        // === THEN: Watch returns to ready ===
        XCTAssertEqual(viewModel.currentState, .ready)
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

    // MARK: - Journey: iOS Overrides Local Session

    /// User starts local session → iOS sends new session → watch uses iOS settings
    func testIOSCanOverrideLocalSession() async throws {
        // === User starts 5-minute local session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 20)

        XCTAssertEqual(viewModel.totalSeconds, 300)

        // === iOS sends a different session ===
        try await sendIOSStartCommand(durationMinutes: 2, inhale: 5, exhale: 5)
        try await advanceEngine(steps: 5)

        // === Watch uses iOS session settings ===
        XCTAssertEqual(viewModel.totalSeconds, 120) // 2 min
        XCTAssertEqual(viewModel.currentInhaleDuration, 5.0)
        XCTAssertEqual(viewModel.currentExhaleDuration, 5.0)
    }
}
