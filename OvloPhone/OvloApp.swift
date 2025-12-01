import SwiftUI

/// Main entry point for the Ovlo iOS app.
///
/// This app runs breathing exercises directly on the iPhone.
@main
struct OvloiOSApp: App {
    @State private var viewModel: BreathingViewModel

    init() {
        let engine = BreathingEngine(hapticController: HapticController())
        self.viewModel = BreathingViewModel(engine: engine)
    }

    var body: some Scene {
        WindowGroup {
            BreathingView(viewModel: viewModel)
        }
    }
}
