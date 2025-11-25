import XCTest
@testable import OvloWatch

/// Tests for iOS-to-Watch communication via WatchConnectivity.
///
/// These tests validate the user experience when controlling the watch from iOS:
/// - iOS app can start breathing sessions on the watch
/// - iOS app can stop active sessions on the watch
/// - Watch handles malformed or incomplete messages gracefully
/// - Rapid commands from iOS are handled correctly
@MainActor
final class WatchConnectivityTests: XCTestCase {
    private var mockConnectivity: MockWatchConnectivity!
    private var testClock: TestClock!
    private var engine: BreathingEngine!
    private var viewModel: BreathingViewModel!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        mockConnectivity = MockWatchConnectivity()
        testClock = TestClock()
        let mockHaptics = MockHapticController()

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
        mockConnectivity = nil
    }

    // MARK: - Test Helpers

    /// Advances the test clock by a specified number of steps.
    private func advanceEngine(steps: Int) async throws {
        for _ in 0..<steps {
            await testClock.advance()
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    /// Simulates the iOS app sending a start command to the watch.
    private func sendStartCommand(durationMinutes: Int, inhale: Int = 4, exhale: Int = 8) async throws {
        let message: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.start.rawValue,
            ConnectivityMessageKey.duration: durationMinutes,
            ConnectivityMessageKey.inhale: inhale,
            ConnectivityMessageKey.exhale: exhale
        ]
        _ = mockConnectivity.simulateReceivingMessage(message)
        try await Task.sleep(for: .milliseconds(50))
    }

    /// Simulates the iOS app sending a stop command to the watch.
    private func sendStopCommand() async throws {
        let message: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.stop.rawValue
        ]
        _ = mockConnectivity.simulateReceivingMessage(message)
        try await Task.sleep(for: .milliseconds(50))
    }

    // MARK: - iOS Start Command Tests

    func testIOSCanStartSessionOnWatch() async throws {
        try await sendStartCommand(durationMinutes: 5)
        try await advanceEngine(steps: 5)
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(viewModel.totalSeconds, 300, "Should configure 5 minute session")
        XCTAssertTrue(
            viewModel.currentState.isActive,
            "Watch should be actively breathing after iOS start command"
        )
    }

    func testIOSCanStartSessionWithCustomTiming() async throws {
        try await sendStartCommand(durationMinutes: 10, inhale: 6, exhale: 10)
        try await advanceEngine(steps: 3)

        // totalSeconds reflects actual duration based on complete cycles
        // 10 min = 600s, cycle = 16s (6+10), 37 complete cycles = 592s
        XCTAssertEqual(viewModel.totalSeconds, 592, "Should configure session with complete cycles")
        XCTAssertEqual(viewModel.currentInhaleDuration, 6.0, "Should use custom inhale timing")
        XCTAssertEqual(viewModel.currentExhaleDuration, 10.0, "Should use custom exhale timing")
    }

    // MARK: - iOS Stop Command Tests

    func testIOSCanStopActiveSession() async throws {
        // Start a session from iOS
        try await sendStartCommand(durationMinutes: 5)
        try await advanceEngine(steps: 5)

        XCTAssertTrue(viewModel.currentState.isActive, "Session should be active")

        // Stop from iOS
        try await sendStopCommand()

        XCTAssertEqual(
            viewModel.currentState,
            .ready,
            "Watch should return to ready after iOS stop command"
        )
    }

    // MARK: - Error Handling Tests

    func testWatchIgnoresMalformedMessages() async throws {
        let invalidMessage: [String: Any] = [
            "garbage": "data",
            "random": 123
        ]

        _ = mockConnectivity.simulateReceivingMessage(invalidMessage)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(
            viewModel.currentState,
            .ready,
            "Watch should remain ready and not crash on malformed message"
        )
    }

    func testWatchIgnoresStartWithoutDuration() async throws {
        let incompleteMessage: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.start.rawValue
            // Missing duration
        ]

        _ = mockConnectivity.simulateReceivingMessage(incompleteMessage)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(
            viewModel.currentState,
            .ready,
            "Watch should not start session without duration parameter"
        )
    }

    // MARK: - Rapid Command Tests

    func testRapidRestartFromIOSUsesLatestSettings() async throws {
        // User starts 5-minute session
        try await sendStartCommand(durationMinutes: 5)
        try await advanceEngine(steps: 3)

        XCTAssertEqual(viewModel.totalSeconds, 300)

        // User immediately changes to 10-minute session
        try await sendStartCommand(durationMinutes: 10)
        try await advanceEngine(steps: 3)

        XCTAssertEqual(
            viewModel.totalSeconds,
            600,
            "Watch should use the most recent session settings"
        )
        XCTAssertTrue(
            viewModel.currentState.isActive,
            "Session should still be running after restart"
        )
    }
}
