import SwiftUI

/// Main entry point for the Ovlo iOS companion app.
///
/// This app allows users to remotely control breathing sessions
/// on their Apple Watch via WatchConnectivity.
@main
struct OvloiOSApp: App {
    @State private var viewModel: SessionControlViewModel

    init() {
        let connectivity = WatchConnectivityManager()
        self.viewModel = SessionControlViewModel(connectivity: connectivity)

        // Activate connectivity on launch
        connectivity.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
