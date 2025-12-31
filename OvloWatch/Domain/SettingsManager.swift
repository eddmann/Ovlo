import Foundation

/// Manages persistent user settings using UserDefaults.
public final class SettingsManager: @unchecked Sendable {
    public static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let selectedChimeName = "selectedChimeName"
        // Breathing mode
        static let breathingDuration = "breathingDuration"
        static let breathingInhale = "breathingInhale"
        static let breathingExhale = "breathingExhale"
    }

    /// Available bundled chimes loaded from chimes.json.
    public static var availableChimes: [AudioConfigEntry] {
        AudioConfigLoader.chimes
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

    /// The name of the selected chime sound.
    /// Defaults to the first entry in chimes.json.
    public var selectedChimeName: String {
        get { defaults.string(forKey: Keys.selectedChimeName) ?? AudioConfigLoader.defaultChimeId }
        set { defaults.set(newValue, forKey: Keys.selectedChimeName) }
    }

    // MARK: - Breathing Mode

    /// Duration for breathing sessions in minutes.
    /// Defaults to 5 minutes for new users.
    public var breathingDuration: Int {
        get {
            let value = defaults.integer(forKey: Keys.breathingDuration)
            return value > 0 ? value : 5
        }
        set { defaults.set(newValue, forKey: Keys.breathingDuration) }
    }

    /// Inhale duration in seconds.
    /// Defaults to 4 seconds for new users.
    public var breathingInhale: Int {
        get {
            let value = defaults.integer(forKey: Keys.breathingInhale)
            return value > 0 ? value : 4
        }
        set { defaults.set(newValue, forKey: Keys.breathingInhale) }
    }

    /// Exhale duration in seconds.
    /// Defaults to 8 seconds for new users.
    public var breathingExhale: Int {
        get {
            let value = defaults.integer(forKey: Keys.breathingExhale)
            return value > 0 ? value : 8
        }
        set { defaults.set(newValue, forKey: Keys.breathingExhale) }
    }
}
