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
        static let selectedChimeName = "selectedChimeName"
        // Session type
        static let selectedSessionType = "selectedSessionType"
        // Breathing mode
        static let breathingDuration = "breathingDuration"
        static let breathingInhale = "breathingInhale"
        static let breathingExhale = "breathingExhale"
        // Ambient mode
        static let ambientDuration = "ambientDuration"
        static let ambientAudioSourceId = "ambientAudioSourceId"
        static let ambientAffirmationsEnabled = "ambientAffirmationsEnabled"
        // Guided mode
        static let guidedAudioSourceId = "guidedAudioSourceId"
    }

    /// Default chime ID (first entry in chimes.json).
    public static var defaultChimeId: String {
        BundledAudioSource.chimes.first?.id ?? "tibetan-bell"
    }

    /// Default music track ID (first entry in music.json).
    public static var defaultMusicTrackId: String {
        BundledAudioSource.musicTracks.first?.id ?? "inner-stillness"
    }

    /// Default meditation ID (first entry in meditations.json).
    public static var defaultMeditationId: String {
        BundledAudioSource.meditations.first?.id ?? "morning-light"
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

    /// Whether background music plays during breathing sessions.
    /// Defaults to false (off) for new users.
    public var isMusicEnabled: Bool {
        get { defaults.bool(forKey: Keys.musicEnabled) }
        set { defaults.set(newValue, forKey: Keys.musicEnabled) }
    }

    /// The name of the selected music track.
    /// Defaults to the first entry in music.json.
    public var selectedTrackName: String {
        get { defaults.string(forKey: Keys.selectedTrackName) ?? Self.defaultMusicTrackId }
        set { defaults.set(newValue, forKey: Keys.selectedTrackName) }
    }

    /// The name of the selected chime sound.
    /// Defaults to the first entry in chimes.json.
    public var selectedChimeName: String {
        get { defaults.string(forKey: Keys.selectedChimeName) ?? Self.defaultChimeId }
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

    // MARK: - Session Type

    /// The currently selected session type.
    /// Defaults to .breathe for new users.
    public var selectedSessionType: SessionType {
        get {
            guard let rawValue = defaults.string(forKey: Keys.selectedSessionType),
                  let type = SessionType(rawValue: rawValue) else {
                return .breathe
            }
            return type
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.selectedSessionType) }
    }

    // MARK: - Ambient Mode

    /// Duration for ambient music sessions in minutes.
    /// Defaults to 10 minutes for new users.
    public var ambientDuration: Int {
        get {
            let value = defaults.integer(forKey: Keys.ambientDuration)
            return value > 0 ? value : 10
        }
        set { defaults.set(newValue, forKey: Keys.ambientDuration) }
    }

    /// ID of the selected audio source for ambient mode.
    /// Defaults to the first entry in music.json.
    public var ambientAudioSourceId: String {
        get { defaults.string(forKey: Keys.ambientAudioSourceId) ?? Self.defaultMusicTrackId }
        set { defaults.set(newValue, forKey: Keys.ambientAudioSourceId) }
    }

    /// Whether affirmations are shown during ambient music sessions.
    /// Defaults to false (off) for new users.
    public var isAmbientAffirmationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.ambientAffirmationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.ambientAffirmationsEnabled) }
    }

    // MARK: - Guided Mode

    /// ID of the selected audio source for guided meditation.
    /// Defaults to the first entry in meditations.json.
    public var guidedAudioSourceId: String {
        get { defaults.string(forKey: Keys.guidedAudioSourceId) ?? Self.defaultMeditationId }
        set { defaults.set(newValue, forKey: Keys.guidedAudioSourceId) }
    }
}
