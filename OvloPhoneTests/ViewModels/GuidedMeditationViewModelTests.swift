import Testing
import Foundation
@testable import OvloPhone

@Suite("GuidedMeditationViewModel Tests")
@MainActor
struct GuidedMeditationViewModelTests {

    @Test("Initial state is ready")
    func testInitialState() async {
        let viewModel = GuidedMeditationViewModel()

        #expect(viewModel.playbackState == .ready)
        #expect(viewModel.elapsedSeconds == 0)
        #expect(viewModel.totalSeconds == 0)
        #expect(viewModel.currentMeditationName == nil)
        #expect(viewModel.selectedAudioSourceId == SettingsManager.defaultMeditationId)
    }

    @Test("Start session with URL plays audio")
    func testStartSessionWithURL() async {
        let mockMusicController = MockMusicController()
        let mockIdleTimer = MockIdleTimerController()
        let viewModel = GuidedMeditationViewModel(
            musicController: mockMusicController,
            idleTimerController: mockIdleTimer
        )

        let testURL = URL(fileURLWithPath: "/test/meditation.mp3")
        await viewModel.startSession(with: testURL, name: "Test Meditation")

        #expect(viewModel.playbackState.isPlaying)
        #expect(viewModel.currentMeditationName == "Test Meditation")
        #expect(viewModel.totalSeconds == 60) // Mock returns 60 seconds
        #expect(await mockMusicController.playOnceCount == 1)
        #expect(await mockMusicController.lastPlayedURL == testURL)
        #expect(mockIdleTimer.disableCallCount == 1)
    }

    @Test("Stop session fades out and resets")
    func testStopSession() async {
        let mockMusicController = MockMusicController()
        let mockIdleTimer = MockIdleTimerController()
        let viewModel = GuidedMeditationViewModel(
            musicController: mockMusicController,
            idleTimerController: mockIdleTimer
        )

        let testURL = URL(fileURLWithPath: "/test/meditation.mp3")
        await viewModel.startSession(with: testURL, name: "Test Meditation")
        await viewModel.stopSession()

        #expect(viewModel.playbackState == .ready)
        #expect(viewModel.elapsedSeconds == 0)
        #expect(viewModel.currentMeditationName == nil)
        #expect(await mockMusicController.fadeOutAndStopCount == 1)
        #expect(mockIdleTimer.enableCallCount == 1)
    }

    @Test("Dismiss completion resets all state")
    func testDismissCompletion() async {
        let mockMusicController = MockMusicController()
        let viewModel = GuidedMeditationViewModel(musicController: mockMusicController)

        let testURL = URL(fileURLWithPath: "/test/meditation.mp3")
        await viewModel.startSession(with: testURL, name: "Test Meditation")
        viewModel.dismissCompletion()

        #expect(viewModel.playbackState == .ready)
        #expect(viewModel.elapsedSeconds == 0)
        #expect(viewModel.totalSeconds == 0)
        #expect(viewModel.currentMeditationName == nil)
    }

    @Test("Start session with non-existent audio source does nothing")
    func testStartSessionWithNonExistentSource() async {
        let mockMusicController = MockMusicController()
        let viewModel = GuidedMeditationViewModel(musicController: mockMusicController)

        viewModel.selectedAudioSourceId = "non-existent-audio-id"
        await viewModel.startSession()

        #expect(viewModel.playbackState == .ready)
        #expect(await mockMusicController.playOnceCount == 0)
    }

    @Test("Duration is retrieved from music controller")
    func testDurationRetrieval() async {
        let mockMusicController = MockMusicController()
        await mockMusicController.setMockDuration(120.0)
        let viewModel = GuidedMeditationViewModel(musicController: mockMusicController)

        let testURL = URL(fileURLWithPath: "/test/meditation.mp3")
        await viewModel.startSession(with: testURL, name: "Long Meditation")

        #expect(viewModel.totalSeconds == 120)
        #expect(await mockMusicController.getDurationCount == 1)
    }
}
