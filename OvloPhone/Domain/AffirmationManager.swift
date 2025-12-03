import Foundation

/// Manages affirmation storage, retrieval, and cycling during breathing sessions.
public final class AffirmationManager: @unchecked Sendable {
    public static let shared = AffirmationManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let customAffirmations = "customAffirmations"
    }

    /// Default affirmations used when user hasn't customized their list.
    public static let defaultAffirmations: [String] = [
        "You are calm and centered",
        "Each breath brings peace",
        "You are present in this moment",
        "Let go of what you cannot control",
        "Breathe in strength, exhale tension",
        "You are exactly where you need to be",
        "Trust the process",
        "This moment is yours"
    ]

    private var shuffledAffirmations: [String] = []
    private var currentIndex: Int = 0

    private init() {}

    /// Returns user's custom affirmations, or defaults if none set.
    public var affirmations: [String] {
        get {
            if let custom = defaults.stringArray(forKey: Keys.customAffirmations), !custom.isEmpty {
                return custom
            }
            return Self.defaultAffirmations
        }
        set {
            defaults.set(newValue, forKey: Keys.customAffirmations)
            shuffle()
        }
    }

    /// Returns true if user has customized their affirmations.
    public var hasCustomAffirmations: Bool {
        defaults.stringArray(forKey: Keys.customAffirmations) != nil
    }

    /// Resets affirmations to the default list.
    public func resetToDefaults() {
        defaults.removeObject(forKey: Keys.customAffirmations)
        shuffle()
    }

    /// Shuffles the affirmations for a new session.
    /// Call this at the start of each breathing session.
    public func shuffle() {
        shuffledAffirmations = affirmations.shuffled()
        currentIndex = 0
    }

    /// Returns the next affirmation in the shuffled sequence.
    /// Wraps around when reaching the end.
    public func nextAffirmation() -> String {
        if shuffledAffirmations.isEmpty {
            shuffle()
        }
        let affirmation = shuffledAffirmations[currentIndex]
        currentIndex = (currentIndex + 1) % shuffledAffirmations.count
        return affirmation
    }
}
