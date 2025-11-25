import SwiftUI

/// Main view for the iOS companion app.
///
/// Provides a minimal interface to start breathing sessions on the watch,
/// with a settings sheet to configure duration and breath timing.
struct ContentView: View {
    @Bindable var viewModel: SessionControlViewModel
    @State private var selectedDuration: Int = 5
    @State private var selectedInhale: Int = 4
    @State private var selectedExhale: Int = 8
    @State private var showingSettings = false

    init(viewModel: SessionControlViewModel) {
        self.viewModel = viewModel
    }

    private let gradientColors: [Color] = [
        Color(red: 0.02, green: 0.08, blue: 0.18),
        Color(red: 0.04, green: 0.20, blue: 0.35),
        Color(red: 0.05, green: 0.35, blue: 0.45)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Ovlo")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("\(selectedInhale)-\(selectedExhale) ~ \(selectedDuration) min")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))

                connectionStatusView

                Spacer()

                controlButton

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .disabled(viewModel.isSessionActive)

                if let error = viewModel.connectionError {
                    errorView(error)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                selectedDuration: $selectedDuration,
                selectedInhale: $selectedInhale,
                selectedExhale: $selectedExhale
            )
        }
    }

    // MARK: - Subviews

    private var connectionStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(viewModel.isConnected ? "Watch Connected" : "Watch Not Connected")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private let accentCyan = Color(red: 0.25, green: 0.95, blue: 0.88)

    private var controlButton: some View {
        Button(action: toggleSession) {
            Group {
                if viewModel.isSessionActive {
                    Image(systemName: "stop.fill")
                } else {
                    Image(systemName: "play.fill")
                }
            }
            .font(.largeTitle)
            .foregroundColor(viewModel.isSessionActive ? .white : Color(red: 0.02, green: 0.08, blue: 0.18))
            .frame(width: 100, height: 100)
            .background(
                Circle()
                    .fill(viewModel.isSessionActive ? Color.red : accentCyan)
                    .shadow(color: accentCyan.opacity(0.5), radius: viewModel.isSessionActive ? 0 : 20)
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isConnected)
        .opacity(viewModel.isConnected ? 1.0 : 0.5)
    }

    private func errorView(_ error: String) -> some View {
        Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
            )
    }

    // MARK: - Actions

    private func toggleSession() {
        if viewModel.isSessionActive {
            viewModel.stopSession()
        } else {
            viewModel.startSession(
                durationMinutes: selectedDuration,
                inhale: selectedInhale,
                exhale: selectedExhale
            )
        }
    }
}

// MARK: - Settings View

/// Settings view for adjusting breathing session parameters.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDuration: Int
    @Binding var selectedInhale: Int
    @Binding var selectedExhale: Int

    private let durationOptions = [1, 2, 5, 10, 15]
    private let breathOptions = [4, 5, 6, 7, 8, 10, 12]

    var body: some View {
        NavigationStack {
            List {
                Picker("Duration", selection: $selectedDuration) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }

                Picker("Inhale", selection: $selectedInhale) {
                    ForEach(breathOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }

                Picker("Exhale", selection: $selectedExhale) {
                    ForEach(breathOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Main View") {
    @Previewable @State var viewModel = SessionControlViewModel(
        connectivity: WatchConnectivityManager()
    )

    ContentView(viewModel: viewModel)
}

#Preview("Settings") {
    @Previewable @State var duration = 5
    @Previewable @State var inhale = 4
    @Previewable @State var exhale = 8

    SettingsView(
        selectedDuration: $duration,
        selectedInhale: $inhale,
        selectedExhale: $exhale
    )
}
