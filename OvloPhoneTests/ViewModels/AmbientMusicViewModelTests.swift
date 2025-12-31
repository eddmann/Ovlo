import Testing
import Foundation
@testable import OvloPhone

@Suite("AmbientMusicViewModel Tests")
@MainActor
struct AmbientMusicViewModelTests {

    @Test("Initial state is ready")
    func testInitialState() async {
        let viewModel = AmbientMusicViewModel()

        #expect(viewModel.playbackState == .ready)
        #expect(viewModel.elapsedSeconds == 0)
        #expect(viewModel.totalSeconds == 0)
        #expect(viewModel.currentTrackName == nil)
        #expect(viewModel.selectedDuration == 10)
        #expect(viewModel.selectedAudioSourceId == "inner-stillness")
    }

    @Test("Start session plays bundled track")
    func testStartSessionWithBundledTrack() async {
        let mockMusicController = MockMusicController()
        let mockIdleTimer = MockIdleTimerController()
        let viewModel = AmbientMusicViewModel(
            musicController: mockMusicController,
            idleTimerController: mockIdleTimer
        )

        viewModel.selectedDuration = 5
        viewModel.selectedAudioSourceId = "dawn-chorus"

        await viewModel.startSession()

        #expect(viewModel.playbackState.isPlaying)
        #expect(viewModel.totalSeconds == 300) // 5 minutes
        #expect(viewModel.currentTrackName == "Dawn Chorus")
        #expect(await mockMusicController.startPlaybackCount == 1)
        #expect(await mockMusicController.lastPlayedTrack == "dawn-chorus")
        #expect(mockIdleTimer.disableCallCount == 1)
    }

    @Test("Stop session fades out and resets")
    func testStopSession() async {
        let mockMusicController = MockMusicController()
        let mockIdleTimer = MockIdleTimerController()
        let viewModel = AmbientMusicViewModel(
            musicController: mockMusicController,
            idleTimerController: mockIdleTimer
        )

        await viewModel.startSession()
        await viewModel.stopSession()

        #expect(viewModel.playbackState == .ready)
        #expect(viewModel.elapsedSeconds == 0)
        #expect(viewModel.currentTrackName == nil)
        #expect(await mockMusicController.fadeOutAndStopCount == 1)
        #expect(await mockMusicController.lastFadeOutDuration == 2.0)
        #expect(mockIdleTimer.enableCallCount == 1)
    }

    @Test("Dismiss completion resets state")
    func testDismissCompletion() async {
        let viewModel = AmbientMusicViewModel()

        await viewModel.startSession()
        viewModel.dismissCompletion()

        #expect(viewModel.playbackState == .ready)
        #expect(viewModel.elapsedSeconds == 0)
        #expect(viewModel.currentTrackName == nil)
    }

    @Test("Duration options set correctly")
    func testDurationSettings() async {
        let viewModel = AmbientMusicViewModel()

        viewModel.selectedDuration = 30

        await viewModel.startSession()

        #expect(viewModel.totalSeconds == 1800) // 30 minutes in seconds
    }
}
