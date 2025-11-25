import XCTest
@testable import OvloWatch

/// Tests for BreathingViewModel - the coordination layer between UI and engine.
///
/// These tests validate user-facing behaviors on the watch:
/// - Starting sessions locally (tapping play)
/// - Stopping sessions (returning to start screen)
/// - Completing sessions early (swipe up gesture)
/// - Settings affect session configuration
/// - Elapsed time tracking during sessions
@MainActor
final class BreathingViewModelTests: XCTestCase {
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

    // MARK: - Local Session Tests

    func testUserTapsPlayToStartSession() async throws {
        // User sees ready state initially
        XCTAssertEqual(viewModel.currentState, .ready)

        // User taps play button
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 5)
        try await Task.sleep(for: .milliseconds(10))

        // Session should be running
        XCTAssertTrue(
            viewModel.currentState.isActive,
            "Session should be active after tapping play"
        )
        XCTAssertGreaterThan(viewModel.totalSeconds, 0, "Total duration should be set")
    }

    func testUserCanConfigureSessionBeforeStarting() async throws {
        // User adjusts settings
        viewModel.selectedDuration = 10  // 10 minutes
        viewModel.selectedInhale = 5     // 5 second inhale
        viewModel.selectedExhale = 10    // 10 second exhale

        // User starts session
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 3)

        // Session should use custom settings
        XCTAssertEqual(viewModel.currentInhaleDuration, 5.0)
        XCTAssertEqual(viewModel.currentExhaleDuration, 10.0)

        // 10 min = 600s, cycle = 15s, 40 cycles = 600s (exact fit)
        XCTAssertEqual(viewModel.totalSeconds, 600)
    }

    func testDefaultSettingsAreReasonable() async throws {
        // Verify sensible defaults for new users
        XCTAssertEqual(viewModel.selectedDuration, 5, "Default duration should be 5 minutes")
        XCTAssertEqual(viewModel.selectedInhale, 4, "Default inhale should be 4 seconds")
        XCTAssertEqual(viewModel.selectedExhale, 8, "Default exhale should be 8 seconds")
    }

    // MARK: - Stop Session Tests

    func testUserTapsDoneToReturnToStart() async throws {
        // Start a session
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 10)

        XCTAssertTrue(viewModel.currentState.isActive)

        // User stops the session
        await viewModel.stopSession()

        // Give state propagation time
        try await Task.sleep(for: .milliseconds(50))

        // Should return to ready state
        XCTAssertEqual(viewModel.currentState, .ready)
        XCTAssertEqual(viewModel.elapsedSeconds, 0, "Elapsed time should reset")
    }

    // MARK: - Early Completion Tests

    func testUserSwipesUpToCompleteEarly() async throws {
        // Start a session
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 30)

        XCTAssertTrue(viewModel.currentState.isActive)

        // User swipes up to complete early
        await viewModel.completeSessionEarly()

        // Should show completion state (not ready)
        XCTAssertEqual(
            viewModel.currentState,
            .completed,
            "Early completion should show completed screen, not return to ready"
        )
    }

    func testAfterEarlyCompletionUserCanReturnToStart() async throws {
        // Start and complete early
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 10)
        await viewModel.completeSessionEarly()

        // Note: completeSessionEarly sets state to .completed, but the state observation
        // may receive .ready from engine.stop() and overwrite it. This is a known race condition.
        // The test verifies the final user flow still works.

        // User taps "Done" on completion screen (or we're already at ready)
        await viewModel.stopSession()

        // Give state propagation time
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.currentState, .ready)
    }

    // MARK: - State Observation Tests

    func testViewModelReflectsEngineStateChanges() async throws {
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // Advance into inhale
        try await advanceEngine(steps: 10)
        try await Task.sleep(for: .milliseconds(10))

        if case .inhaling = viewModel.currentState {
            // Good - in inhale
        } else {
            XCTFail("ViewModel should reflect inhaling state")
        }

        // Advance into exhale
        try await advanceEngine(steps: stepsPerPhase)
        try await Task.sleep(for: .milliseconds(10))

        if case .exhaling = viewModel.currentState {
            // Good - in exhale
        } else {
            XCTFail("ViewModel should reflect exhaling state")
        }
    }

    // MARK: - Duration Display Tests

    func testTotalSecondsReflectsActualSessionDuration() async throws {
        // With 5 min and 12s cycle (4+8), we get 25 cycles = 300s
        viewModel.selectedDuration = 5
        viewModel.selectedInhale = 4
        viewModel.selectedExhale = 8

        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // 5 min = 300s, 12s cycle = 25 complete cycles = 300s
        XCTAssertEqual(viewModel.totalSeconds, 300)
    }
}
