import SwiftUI

/// Start screen for initiating a breathing session on iOS.
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

            VStack(spacing: 16) {
                Spacer()

                Text("Ovlo")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("\(selectedInhale)-\(selectedExhale) ~ \(selectedDuration) min")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundColor(Color(red: 0.02, green: 0.08, blue: 0.18))
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(accentCyan)
                                .shadow(
                                    color: accentCyan.opacity(isPulsing ? 0.8 : 0.4),
                                    radius: isPulsing ? 25 : 15
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
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Spacer()
                    .frame(height: 40)
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

    @State private var soundEnabled = SettingsManager.shared.isSoundEnabled
    @State private var hapticEnabled = SettingsManager.shared.isHapticEnabled
    @State private var musicEnabled = SettingsManager.shared.isMusicEnabled
    @State private var selectedTrackName = SettingsManager.shared.selectedTrackName
    @State private var selectedChimeName = SettingsManager.shared.selectedChimeName
    @State private var affirmationsEnabled = SettingsManager.shared.isAffirmationsEnabled
    @State private var isPreviewPlaying = false

    private let durationOptions = [1, 2, 5, 10, 15]
    private let breathOptions = [4, 5, 6, 7, 8, 10, 12]
    private let previewController = MusicController()
    private let chimePreviewController = AudioController()

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
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

                Section {
                    Toggle("Chime", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { _, newValue in
                            SettingsManager.shared.isSoundEnabled = newValue
                        }
                    if soundEnabled {
                        Picker("Sound", selection: $selectedChimeName) {
                            Text("Tibetan Bell").tag("tibetan-bell")
                            Text("Crystal Chime").tag("crystal-chime")
                            Text("Zen Garden").tag("zen-garden")
                            Text("Temple Gong").tag("temple-gong")
                            Text("Twin Bells").tag("twin-bells")
                            Text("Bright Bell").tag("bright-bell")
                        }
                        .onChange(of: selectedChimeName) { _, newValue in
                            SettingsManager.shared.selectedChimeName = newValue
                        }

                        Button {
                            Task {
                                await chimePreviewController.playChime(named: selectedChimeName)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Preview Chime")
                            }
                        }
                    }
                    Toggle("Haptics", isOn: $hapticEnabled)
                        .onChange(of: hapticEnabled) { _, newValue in
                            SettingsManager.shared.isHapticEnabled = newValue
                        }
                } header: {
                    Text("Transitions")
                } footer: {
                    Text("Feedback when switching between inhale and exhale")
                }

                Section("Background Music") {
                    Toggle("Music", isOn: $musicEnabled)
                        .onChange(of: musicEnabled) { _, newValue in
                            SettingsManager.shared.isMusicEnabled = newValue
                            if !newValue {
                                Task {
                                    await previewController.stopPlayback()
                                    isPreviewPlaying = false
                                }
                            }
                        }
                    if musicEnabled {
                        Picker("Track", selection: $selectedTrackName) {
                            Text("Dawn Chorus").tag("dawn-chorus")
                            Text("Ethereal Horizons").tag("ethereal-horizons")
                            Text("Golden Hour").tag("golden-hour")
                            Text("Inner Stillness").tag("inner-stillness")
                            Text("Tidal Serenity").tag("tidal-serenity")
                            Text("Tranquil Meadow").tag("tranquil-meadow")
                            Text("Whispering Brook").tag("whispering-brook")
                        }
                        .onChange(of: selectedTrackName) { _, newValue in
                            SettingsManager.shared.selectedTrackName = newValue
                            if isPreviewPlaying {
                                Task {
                                    await previewController.startPlayback(trackName: newValue)
                                }
                            }
                        }

                        Button {
                            Task {
                                if isPreviewPlaying {
                                    await previewController.stopPlayback()
                                    isPreviewPlaying = false
                                } else {
                                    await previewController.startPlayback(trackName: selectedTrackName)
                                    isPreviewPlaying = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPreviewPlaying ? "stop.fill" : "play.fill")
                                Text(isPreviewPlaying ? "Stop Preview" : "Preview Track")
                            }
                        }
                    }
                }

                Section {
                    Toggle("Affirmations", isOn: $affirmationsEnabled)
                        .onChange(of: affirmationsEnabled) { _, newValue in
                            SettingsManager.shared.isAffirmationsEnabled = newValue
                        }
                    if affirmationsEnabled {
                        NavigationLink("Customize") {
                            AffirmationSettingsView()
                        }
                    }
                } header: {
                    Text("Affirmations")
                } footer: {
                    Text("Positive messages shown during your session")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await previewController.stopPlayback()
                        }
                        dismiss()
                    }
                }
            }
            .onDisappear {
                Task {
                    await previewController.stopPlayback()
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
