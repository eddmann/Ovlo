import SwiftUI

/// Main entry point for the Ovlo watchOS app.
///
/// This app runs the breathing exercise logic on the watch.
@main
struct OvloWatchApp: App {
    @State private var viewModel: BreathingViewModel

    #if DEBUG
    private let shouldAutoStart: Bool
    #endif

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

        #if DEBUG
        if let demoMode = DemoMode.fromArguments() {
            self.shouldAutoStart = DemoStateFactory.configure(for: demoMode)
        } else {
            self.shouldAutoStart = false
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            BreathingView(viewModel: viewModel, demoAutoStart: shouldAutoStart)
            #else
            BreathingView(viewModel: viewModel)
            #endif
        }
    }
}
