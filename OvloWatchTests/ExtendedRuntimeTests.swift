import XCTest
@testable import OvloWatch

/// Tests for extended runtime session management.
///
/// These tests validate that breathing sessions continue running when the watch screen dims:
/// - Sessions request background execution time when started
/// - Sessions release background execution when stopped or completed
/// - Users can still breathe without watching the screen
/// - Haptic feedback continues even with screen dimmed
@MainActor
final class ExtendedRuntimeTests: XCTestCase {
    private var viewModel: BreathingViewModel!
    private var engine: BreathingEngine!
    private var testClock: TestClock!
    private var mockHaptics: MockHapticController!
    private var mockRuntimeController: MockExtendedRuntimeController!

    // MARK: - Constants

    private let stepsPerPhase = 60
    private var stepsPerCycle: Int { stepsPerPhase * 2 }

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        testClock = TestClock()
        mockHaptics = MockHapticController()
        mockRuntimeController = MockExtendedRuntimeController()

        engine = BreathingEngine(
            clock: testClock,
            hapticController: mockHaptics
        )

        viewModel = BreathingViewModel(
            engine: engine,
            extendedRuntimeController: mockRuntimeController
        )
    }

    override func tearDown() async throws {
        await engine.stop()
        viewModel = nil
        engine = nil
        testClock = nil
        mockHaptics = nil
        mockRuntimeController = nil
    }

    // MARK: - Test Helpers

    /// Advances the test clock by a specified number of steps, allowing the engine to progress.
    private func advanceEngine(steps: Int) async throws {
        for _ in 0..<steps {
            await testClock.advance()
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    // MARK: - Background Execution When Session Starts

    func testSessionRequestsBackgroundExecutionOnStart() async throws {
        // === GIVEN: User is on start screen ===
        let initialCount = await mockRuntimeController.startSessionCallCount
        XCTAssertEqual(initialCount, 0, "No background execution requested yet")

        // === WHEN: User starts a breathing session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: App requests permission to run with screen dimmed ===
        let finalCount = await mockRuntimeController.startSessionCallCount
        XCTAssertEqual(finalCount, 1, "Should request background execution when session starts")

        let isActive = await mockRuntimeController.isSessionActive
        XCTAssertTrue(isActive, "Background execution should be active")
    }

    // MARK: - Background Execution Released When Session Ends

    func testUserStoppingSessionReleasesBackgroundExecution() async throws {
        // === GIVEN: User is mid-session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // === WHEN: User stops the session ===
        await viewModel.stopSession()
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: Background execution is released to save battery ===
        let invalidateCount = await mockRuntimeController.invalidateSessionCallCount
        XCTAssertEqual(invalidateCount, 1, "Should release background execution when user stops")

        let isActive = await mockRuntimeController.isSessionActive
        XCTAssertFalse(isActive, "Background execution should no longer be active")
    }

    func testCompletedSessionReleasesBackgroundExecution() async throws {
        // === GIVEN: User starts a short 1-minute session ===
        viewModel.selectedDuration = 1
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // === WHEN: Session completes naturally ===
        let totalSteps = stepsPerCycle * 5  // 1 min = 5 cycles
        try await advanceEngine(steps: totalSteps)
        try await Task.sleep(for: .milliseconds(50))

        // === THEN: Session completed successfully ===
        XCTAssertEqual(viewModel.currentState, .completed, "Session should complete")

        // === AND: Background execution is released ===
        let invalidateCount = await mockRuntimeController.invalidateSessionCallCount
        XCTAssertEqual(invalidateCount, 1, "Should release background execution when session completes")

        let isActive = await mockRuntimeController.isSessionActive
        XCTAssertFalse(isActive, "Background execution should no longer be active")
    }

    func testSwipeToCompleteReleasesBackgroundExecution() async throws {
        // === GIVEN: User is mid-session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 30)

        // === WHEN: User swipes up to complete early ===
        await viewModel.completeSessionEarly()
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: Background execution is released ===
        let invalidateCount = await mockRuntimeController.invalidateSessionCallCount
        XCTAssertEqual(invalidateCount, 1, "Early completion should release background execution")

        let isActive = await mockRuntimeController.isSessionActive
        XCTAssertFalse(isActive)
    }

    // MARK: - Multiple Sessions

    func testRestartingSessionRequestsNewBackgroundExecution() async throws {
        // === GIVEN: User completes first session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        await viewModel.stopSession()
        try await Task.sleep(for: .milliseconds(10))

        // === WHEN: User starts a new session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: New background execution is requested ===
        let startCount = await mockRuntimeController.startSessionCallCount
        XCTAssertEqual(startCount, 2, "Each session start should request background execution")

        // === AND: Previous session's execution was properly released ===
        let invalidateCount = await mockRuntimeController.invalidateSessionCallCount
        XCTAssertEqual(invalidateCount, 1, "First session should have released execution")
    }

    // MARK: - Graceful Degradation

    func testAppWorksWithoutBackgroundExecutionController() async throws {
        // === GIVEN: ViewModel created without extended runtime controller ===
        // (This could happen on older OS versions or if entitlements are missing)
        let viewModelWithoutRuntime = BreathingViewModel(
            engine: engine
            // No extendedRuntimeController provided
        )

        // === WHEN: User starts a session ===
        await viewModelWithoutRuntime.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))
        try await advanceEngine(steps: 5)

        // === THEN: Session works normally (no crash) ===
        XCTAssertTrue(
            viewModelWithoutRuntime.currentState.isActive,
            "Session should work even without background execution support"
        )

        // === AND: Mock was never called (verifies isolation) ===
        let startCount = await mockRuntimeController.startSessionCallCount
        XCTAssertEqual(startCount, 0, "Should not affect other view models")
    }

    func testBackgroundExecutionTransitionsToRunningState() async throws {
        // === GIVEN: Fresh runtime controller ===
        await mockRuntimeController.reset()

        // === WHEN: User starts session ===
        await viewModel.startLocalSession()
        try await Task.sleep(for: .milliseconds(10))

        // === THEN: Runtime state is running (ready for screen to dim) ===
        let state = await mockRuntimeController.state
        XCTAssertEqual(state, .running, "Background execution should be in running state")
    }
}
