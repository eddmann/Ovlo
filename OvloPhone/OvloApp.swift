import SwiftUI

/// Main entry point for the Ovlo iOS app.
///
/// This app supports three session types: breathing, ambient music, and guided meditation.
@main
struct OvloiOSApp: App {
    @State private var breathingViewModel: BreathingViewModel
    @State private var ambientViewModel: AmbientMusicViewModel
    @State private var guidedViewModel: GuidedMeditationViewModel

    init() {
        let engine = BreathingEngine(hapticController: HapticController())
        self.breathingViewModel = BreathingViewModel(engine: engine)
        self.ambientViewModel = AmbientMusicViewModel()
        self.guidedViewModel = GuidedMeditationViewModel()
    }

    var body: some Scene {
        WindowGroup {
            MainSessionView(
                breathingViewModel: breathingViewModel,
                ambientViewModel: ambientViewModel,
                guidedViewModel: guidedViewModel
            )
        }
    }
}
