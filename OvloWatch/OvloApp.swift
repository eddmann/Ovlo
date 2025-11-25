import SwiftUI

/// Main entry point for the Ovlo watchOS app.
///
/// This app runs the breathing exercise logic on the watch and responds
/// to commands sent from the iOS companion app via WatchConnectivity.
@main
struct OvloWatchApp: App {
    @State private var viewModel: BreathingViewModel

    init() {
        let connectivity = WatchConnectivityManager()
        let engine = BreathingEngine()
        self.viewModel = BreathingViewModel(
            engine: engine,
            connectivity: connectivity
        )

        // Activate connectivity on launch
        connectivity.activate()
    }

    var body: some Scene {
        WindowGroup {
            BreathingView(viewModel: viewModel)
        }
    }
}
