import Foundation

/// State of audio playback for guided meditation and ambient music sessions.
public enum PlaybackState: Sendable, Equatable {
    case ready
    case playing(progress: Double)
    case paused(progress: Double)
    case completed

    /// Whether the session is currently active (playing or paused).
    public var isActive: Bool {
        switch self {
        case .playing, .paused:
            return true
        case .ready, .completed:
            return false
        }
    }

    /// Whether audio is currently playing.
    public var isPlaying: Bool {
        if case .playing = self {
            return true
        }
        return false
    }

    /// Current progress value (0.0 to 1.0).
    public var progress: Double {
        switch self {
        case .ready:
            return 0.0
        case .playing(let progress), .paused(let progress):
            return progress
        case .completed:
            return 1.0
        }
    }

    /// Display text for the current state.
    public var displayText: String {
        switch self {
        case .ready:
            return "Ready"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .completed:
            return "Complete"
        }
    }
}
