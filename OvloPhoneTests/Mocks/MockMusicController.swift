import Foundation
@testable import OvloPhone

/// Mock music controller for testing.
/// Records calls without playing actual music.
public actor MockMusicController: MusicControllerProtocol {
    public private(set) var startPlaybackCount = 0
    public private(set) var stopPlaybackCount = 0
    public private(set) var fadeOutAndStopCount = 0
    public private(set) var playOnceCount = 0
    public private(set) var getDurationCount = 0
    public private(set) var lastFadeOutDuration: TimeInterval?
    public private(set) var lastPlayedTrack: String?
    public private(set) var lastPlayedURL: URL?
    public private(set) var currentTime: TimeInterval = 0
    public var mockDuration: TimeInterval? = 60.0
    private var playOnceCompletion: (@Sendable () -> Void)?

    public init() {}

    @MainActor
    public func startPlayback(trackName: String) async {
        await recordStart(trackName: trackName)
    }

    @MainActor
    public func startPlayback(url: URL) async {
        await recordStartURL(url: url)
    }

    @MainActor
    public func playOnce(url: URL, onComplete: @escaping @Sendable () -> Void) async {
        await recordPlayOnce(url: url, onComplete: onComplete)
    }

    @MainActor
    public func getDuration(for url: URL) async -> TimeInterval? {
        return await recordGetDuration()
    }

    @MainActor
    public func getCurrentTime() async -> TimeInterval {
        return await getStoredCurrentTime()
    }

    private func getStoredCurrentTime() -> TimeInterval {
        currentTime
    }

    private func recordStart(trackName: String) {
        startPlaybackCount += 1
        lastPlayedTrack = trackName
    }

    private func recordStartURL(url: URL) {
        startPlaybackCount += 1
        lastPlayedURL = url
    }

    private func recordPlayOnce(url: URL, onComplete: @escaping @Sendable () -> Void) {
        playOnceCount += 1
        lastPlayedURL = url
        playOnceCompletion = onComplete
    }

    private func recordGetDuration() -> TimeInterval? {
        getDurationCount += 1
        return mockDuration
    }

    @MainActor
    public func stopPlayback() async {
        await recordStop()
    }

    private func recordStop() {
        stopPlaybackCount += 1
    }

    @MainActor
    public func fadeOutAndStop(duration: TimeInterval) async {
        await recordFadeOut(duration: duration)
    }

    private func recordFadeOut(duration: TimeInterval) {
        fadeOutAndStopCount += 1
        lastFadeOutDuration = duration
    }

    /// Simulates playback completion for playOnce.
    public func simulatePlaybackComplete() {
        playOnceCompletion?()
        playOnceCompletion = nil
    }

    /// Sets the current playback time for testing.
    public func setCurrentTime(_ time: TimeInterval) {
        currentTime = time
    }

    /// Sets the mock duration for testing.
    public func setMockDuration(_ duration: TimeInterval?) {
        mockDuration = duration
    }

    /// Resets all recorded state.
    public func reset() {
        startPlaybackCount = 0
        stopPlaybackCount = 0
        fadeOutAndStopCount = 0
        playOnceCount = 0
        getDurationCount = 0
        lastFadeOutDuration = nil
        lastPlayedTrack = nil
        lastPlayedURL = nil
        currentTime = 0
        playOnceCompletion = nil
    }
}
