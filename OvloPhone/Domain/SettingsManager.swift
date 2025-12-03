import Foundation

/// Manages persistent user settings using UserDefaults.
public final class SettingsManager: @unchecked Sendable {
    public static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let affirmationsEnabled = "affirmationsEnabled"
        static let musicEnabled = "musicEnabled"
        static let selectedTrackName = "selectedTrackName"
    }

    /// Available bundled music tracks.
    public static let availableTracks = [
        "dawn-chorus",
        "ethereal-horizons",
        "golden-hour",
        "inner-stillness",
        "tidal-serenity",
        "tranquil-meadow",
        "whispering-brook",
        "woodland-rainfall"
    ]

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

    /// Whether background music plays during breathing sessions.
    /// Defaults to false (off) for new users.
    public var isMusicEnabled: Bool {
        get { defaults.bool(forKey: Keys.musicEnabled) }
        set { defaults.set(newValue, forKey: Keys.musicEnabled) }
    }

    /// The name of the selected music track.
    /// Defaults to "inner-stillness" for new users.
    public var selectedTrackName: String {
        get { defaults.string(forKey: Keys.selectedTrackName) ?? "inner-stillness" }
        set { defaults.set(newValue, forKey: Keys.selectedTrackName) }
    }
}
