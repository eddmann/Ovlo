import SwiftUI

/// Main entry point for the Ovlo iOS app.
///
/// This app supports three session types: breathing, ambient music, and guided meditation.
@main
struct OvloiOSApp: App {
    @State private var breathingViewModel: BreathingViewModel
    @State private var ambientViewModel: AmbientMusicViewModel
    @State private var guidedViewModel: GuidedMeditationViewModel

    #if DEBUG
    private let demoSessionType: SessionType?
    #endif

    init() {
        let engine = BreathingEngine(hapticController: HapticController())
        self.breathingViewModel = BreathingViewModel(engine: engine)
        self.ambientViewModel = AmbientMusicViewModel()
        self.guidedViewModel = GuidedMeditationViewModel()

        #if DEBUG
        if let demoMode = DemoMode.fromArguments() {
            self.demoSessionType = DemoStateFactory.configure(for: demoMode)
        } else {
            self.demoSessionType = nil
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            MainSessionView(
                breathingViewModel: breathingViewModel,
                ambientViewModel: ambientViewModel,
                guidedViewModel: guidedViewModel,
                demoSessionType: demoSessionType
            )
            #else
            MainSessionView(
                breathingViewModel: breathingViewModel,
                ambientViewModel: ambientViewModel,
                guidedViewModel: guidedViewModel
            )
            #endif
        }
    }
}
