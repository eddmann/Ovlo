import Foundation

/// Represents the current state of a breathing exercise session.
///
/// The breathing state machine transitions through these states:
/// Ready → Inhaling → Exhaling → (repeat) → Completed
public enum BreathingState: Sendable, Equatable {
    /// Session is ready to start but not yet begun
    case ready

    /// Currently in the inhale phase
    /// - Parameter progress: Normalized progress through inhale (0.0 to 1.0)
    case inhaling(progress: Double)

    /// Currently in the exhale phase
    /// - Parameter progress: Normalized progress through exhale (0.0 to 1.0)
    case exhaling(progress: Double)

    /// Session has been completed
    case completed

    /// Returns the display text for the current state
    public var displayText: String {
        switch self {
        case .ready:
            return "Ready"
        case .inhaling:
            return "Breathe In"
        case .exhaling:
            return "Breathe Out"
        case .completed:
            return "Complete"
        }
    }

    /// Returns true if the session is actively running (inhaling or exhaling)
    public var isActive: Bool {
        switch self {
        case .inhaling, .exhaling:
            return true
        case .ready, .completed:
            return false
        }
    }

    /// Returns the progress value (0.0 to 1.0) for active states
    public var progress: Double {
        switch self {
        case .inhaling(let progress), .exhaling(let progress):
            return progress
        case .ready, .completed:
            return 0.0
        }
    }
}
