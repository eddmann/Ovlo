import Foundation

/// Manages persistent user settings using UserDefaults.
public final class SettingsManager: @unchecked Sendable {
    public static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let selectedChimeName = "selectedChimeName"
    }

    /// Available bundled chime sounds.
    public static let availableChimes = [
        "tibetan-bell",
        "crystal-chime",
        "zen-garden",
        "temple-gong",
        "twin-bells",
        "bright-bell"
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

    /// The name of the selected chime sound.
    /// Defaults to "tibetan-bell" for new users.
    public var selectedChimeName: String {
        get { defaults.string(forKey: Keys.selectedChimeName) ?? "tibetan-bell" }
        set { defaults.set(newValue, forKey: Keys.selectedChimeName) }
    }
}
