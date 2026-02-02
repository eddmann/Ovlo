#if DEBUG
import Foundation

/// Factory for configuring demo state for screenshots and testing.
@MainActor
enum DemoStateFactory {
    /// Configures app state for the given demo mode.
    /// Returns the session type to auto-start, if any.
    static func configure(for mode: DemoMode) -> SessionType? {
        configureSettings(for: mode)
        return sessionTypeToStart(for: mode)
    }

    private static func configureSettings(for mode: DemoMode) {
        let settings = SettingsManager.shared

        switch mode {
        case .startView:
            // Default settings, show start screen
            settings.selectedSessionType = .breathe
            settings.breathingDuration = 5
            settings.breathingInhale = 4
            settings.breathingExhale = 8

        case .breathingActive:
            // Breathing without affirmations
            settings.isAffirmationsEnabled = false
            settings.breathingDuration = 5
            settings.breathingInhale = 4
            settings.breathingExhale = 8

        case .breathingAffirmation:
            // Breathing with affirmations enabled
            settings.isAffirmationsEnabled = true
            settings.breathingDuration = 5
            settings.breathingInhale = 4
            settings.breathingExhale = 8

        case .ambientActive:
            // Ambient music session
            settings.ambientDuration = 10
            settings.isAmbientAffirmationsEnabled = true

        case .guidedActive:
            // Guided meditation session
            break
        }
    }

    private static func sessionTypeToStart(for mode: DemoMode) -> SessionType? {
        switch mode {
        case .startView:
            nil
        case .breathingActive, .breathingAffirmation:
            .breathe
        case .ambientActive:
            .ambient
        case .guidedActive:
            .guided
        }
    }
}
#endif
