#if DEBUG
import Foundation

/// Factory for configuring demo state for screenshots and testing.
@MainActor
enum DemoStateFactory {
    /// Configures app state for the given demo mode.
    /// Returns true if the breathing session should auto-start.
    static func configure(for mode: DemoMode) -> Bool {
        configureSettings(for: mode)
        return shouldAutoStart(for: mode)
    }

    private static func configureSettings(for mode: DemoMode) {
        let settings = SettingsManager.shared

        switch mode {
        case .startView:
            // Default settings, show start screen
            settings.breathingDuration = 5
            settings.breathingInhale = 4
            settings.breathingExhale = 8

        case .breathingActive:
            // Breathing session in progress
            settings.breathingDuration = 5
            settings.breathingInhale = 4
            settings.breathingExhale = 8
        }
    }

    private static func shouldAutoStart(for mode: DemoMode) -> Bool {
        switch mode {
        case .startView:
            false
        case .breathingActive:
            true
        }
    }
}
#endif
