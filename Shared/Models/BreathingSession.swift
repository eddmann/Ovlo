import Foundation

/// Represents a breathing exercise session configuration.
///
/// This model defines the parameters for a breathing session including
/// duration and timing for each breathing phase.
public struct BreathingSession: Sendable, Equatable, Codable {
    /// Total duration of the session in seconds
    public let durationSeconds: Int

    /// Duration of the inhale phase in seconds
    public let inhaleDuration: TimeInterval

    /// Duration of the exhale phase in seconds
    public let exhaleDuration: TimeInterval

    /// Total duration of one complete breathing cycle (inhale + exhale)
    public var cycleDuration: TimeInterval {
        inhaleDuration + exhaleDuration
    }

    /// Number of complete breathing cycles in this session
    public var totalCycles: Int {
        Int(Double(durationSeconds) / cycleDuration)
    }

    /// Actual session duration based on complete cycles (may be less than durationSeconds)
    public var actualDurationSeconds: Int {
        totalCycles * Int(cycleDuration)
    }

    /// Creates a new breathing session with the specified parameters.
    /// - Parameters:
    ///   - durationMinutes: Session duration in minutes (1-15)
    ///   - inhaleDuration: Duration of inhale phase in seconds (default: 4)
    ///   - exhaleDuration: Duration of exhale phase in seconds (default: 8)
    public init(durationMinutes: Int, inhaleDuration: TimeInterval = 4.0, exhaleDuration: TimeInterval = 8.0) {
        precondition(durationMinutes >= 1 && durationMinutes <= 15,
                     "Session duration must be between 1 and 15 minutes")
        self.durationSeconds = durationMinutes * 60
        self.inhaleDuration = inhaleDuration
        self.exhaleDuration = exhaleDuration
    }

    /// Creates a breathing session with duration in seconds (for testing).
    /// - Parameters:
    ///   - durationSeconds: Session duration in seconds
    ///   - inhaleDuration: Duration of inhale phase in seconds (default: 4)
    ///   - exhaleDuration: Duration of exhale phase in seconds (default: 8)
    internal init(durationSeconds: Int, inhaleDuration: TimeInterval = 4.0, exhaleDuration: TimeInterval = 8.0) {
        self.durationSeconds = durationSeconds
        self.inhaleDuration = inhaleDuration
        self.exhaleDuration = exhaleDuration
    }
}
