import SwiftUI

/// Start screen for initiating a breathing session directly on the watch.
///
/// Displays a minimal interface with app title, current settings summary,
/// start button, and a settings cog for adjusting session parameters.
struct StartView: View {
    @Binding var selectedDuration: Int
    @Binding var selectedInhale: Int
    @Binding var selectedExhale: Int
    let onStart: () -> Void

    @State private var showingSettings = false
    @State private var isPulsing = false

    private let gradientColors: [Color] = [
        Color(red: 0.02, green: 0.08, blue: 0.18),
        Color(red: 0.04, green: 0.20, blue: 0.35),
        Color(red: 0.05, green: 0.35, blue: 0.45)
    ]

    private let accentCyan = Color(red: 0.25, green: 0.95, blue: 0.88)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer()

                Text("Ovlo")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("\(selectedInhale)-\(selectedExhale) ~ \(selectedDuration) min")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.02, green: 0.08, blue: 0.18))
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(accentCyan)
                                .shadow(
                                    color: accentCyan.opacity(isPulsing ? 0.8 : 0.4),
                                    radius: isPulsing ? 18 : 10
                                )
                        )
                        .scaleEffect(isPulsing ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                }

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                selectedDuration: $selectedDuration,
                selectedInhale: $selectedInhale,
                selectedExhale: $selectedExhale
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

#Preview("Start View") {
    @Previewable @State var duration = 5
    @Previewable @State var inhale = 4
    @Previewable @State var exhale = 8

    StartView(
        selectedDuration: $duration,
        selectedInhale: $inhale,
        selectedExhale: $exhale
    ) {}
}

#Preview("Settings View") {
    @Previewable @State var duration = 5
    @Previewable @State var inhale = 4
    @Previewable @State var exhale = 8

    SettingsView(
        selectedDuration: $duration,
        selectedInhale: $inhale,
        selectedExhale: $exhale
    )
}
