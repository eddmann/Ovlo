import Foundation

/// Manages persistent user settings using UserDefaults.
public final class SettingsManager: @unchecked Sendable {
    public static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let affirmationsEnabled = "affirmationsEnabled"
    }

    private init() {
        // Default haptic to true if not set
        if defaults.object(forKey: Keys.hapticEnabled) == nil {
            defaults.set(true, forKey: Keys.hapticEnabled)
        }
    }

    /// Whether phase transition sounds are enabled.
    /// Defaults to false (off) for new users.
    public var isSoundEnabled: Bool {
        get { defaults.bool(forKey: Keys.soundEnabled) }
        set { defaults.set(newValue, forKey: Keys.soundEnabled) }
    }

    /// Whether haptic feedback is enabled.
    /// Defaults to true (on) for new users.
    public var isHapticEnabled: Bool {
        get { defaults.bool(forKey: Keys.hapticEnabled) }
        set { defaults.set(newValue, forKey: Keys.hapticEnabled) }
    }

    /// Whether affirmations are shown during breathing sessions.
    /// Defaults to false (off) for new users.
    public var isAffirmationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.affirmationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.affirmationsEnabled) }
    }
}
