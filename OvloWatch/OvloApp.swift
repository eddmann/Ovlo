import SwiftUI

/// Main entry point for the Ovlo watchOS app.
///
/// This app runs the breathing exercise logic on the watch.
@main
struct OvloWatchApp: App {
    @State private var viewModel: BreathingViewModel

    init() {
        let engine = BreathingEngine()
        #if os(watchOS)
        let extendedRuntimeController = ExtendedRuntimeController()
        #else
        let extendedRuntimeController: ExtendedRuntimeControllerProtocol? = nil
        #endif
        self.viewModel = BreathingViewModel(
            engine: engine,
            extendedRuntimeController: extendedRuntimeController
        )
    }

    var body: some Scene {
        WindowGroup {
            BreathingView(viewModel: viewModel)
        }
    }
}
