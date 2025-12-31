import SwiftUI
import MediaPlayer

/// Start screen for initiating a session on iOS.
///
/// Displays a minimal interface with session type tabs, app title, current settings summary,
/// start button, and a settings cog for adjusting session parameters.
struct StartView: View {
    @Binding var selectedSessionType: SessionType
    // Breathing mode
    @Binding var selectedDuration: Int
    @Binding var selectedInhale: Int
    @Binding var selectedExhale: Int
    let onStartBreathing: () -> Void
    // Ambient mode
    @Binding var ambientDuration: Int
    @Binding var ambientAudioSourceId: String
    let onStartAmbient: () -> Void
    // Guided mode
    @Binding var guidedAudioSourceId: String
    let onStartGuided: () -> Void

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
                    .frame(height: 40)

                SessionTypePicker(selected: $selectedSessionType)
                    .onChange(of: selectedSessionType) { _, newValue in
                        SettingsManager.shared.selectedSessionType = newValue
                    }

                Spacer()

                Text("Ovlo")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                summaryText
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())

                Spacer()

                Button(action: startAction) {
                    Image(systemName: startButtonIcon)
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
                .disabled(!canStart)
                .opacity(canStart ? 1.0 : 0.5)
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
            settingsSheet
        }
    }

    // MARK: - Computed Properties

    private var summaryText: Text {
        switch selectedSessionType {
        case .breathe:
            return Text("\(selectedInhale)-\(selectedExhale) ~ \(selectedDuration) min")
        case .ambient:
            let trackName = BundledAudioSource.musicTracks.first { $0.id == ambientAudioSourceId }?.displayName ?? "Select Track"
            return Text("\(ambientDuration) min ~ \(trackName)")
        case .guided:
            if let source = BundledAudioSource.meditations.first(where: { $0.id == guidedAudioSourceId }) {
                return Text(source.displayName)
            } else if let imported = ImportedAudioStore.shared.find(id: guidedAudioSourceId) {
                return Text(imported.displayName)
            }
            return Text("Select meditation")
        }
    }

    private var startButtonIcon: String {
        return "play.fill"
    }

    private var canStart: Bool {
        return true
    }

    private func startAction() {
        switch selectedSessionType {
        case .breathe:
            onStartBreathing()
        case .ambient:
            onStartAmbient()
        case .guided:
            onStartGuided()
        }
    }

    @ViewBuilder
    private var settingsSheet: some View {
        switch selectedSessionType {
        case .breathe:
            SettingsView(
                selectedDuration: $selectedDuration,
                selectedInhale: $selectedInhale,
                selectedExhale: $selectedExhale
            )
        case .ambient:
            AmbientSettingsView(
                selectedDuration: $ambientDuration,
                selectedAudioSourceId: $ambientAudioSourceId
            )
        case .guided:
            GuidedSettingsView(
                selectedAudioSourceId: $guidedAudioSourceId
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
                    .onChange(of: selectedDuration) { _, newValue in
                        SettingsManager.shared.breathingDuration = newValue
                    }

                    Picker("Inhale", selection: $selectedInhale) {
                        ForEach(breathOptions, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .onChange(of: selectedInhale) { _, newValue in
                        SettingsManager.shared.breathingInhale = newValue
                    }

                    Picker("Exhale", selection: $selectedExhale) {
                        ForEach(breathOptions, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .onChange(of: selectedExhale) { _, newValue in
                        SettingsManager.shared.breathingExhale = newValue
                    }
                }

                Section {
                    Toggle("Chime", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { _, newValue in
                            SettingsManager.shared.isSoundEnabled = newValue
                        }
                    if soundEnabled {
                        Picker("Sound", selection: $selectedChimeName) {
                            ForEach(BundledAudioSource.chimes, id: \.id) { chime in
                                Text(chime.displayName).tag(chime.id)
                            }
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
                            ForEach(BundledAudioSource.musicTracks, id: \.id) { track in
                                Text(track.displayName).tag(track.fileName)
                            }
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
            .navigationTitle("Breathwork")
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

// MARK: - Ambient Settings View

/// Settings view for ambient music session parameters.
struct AmbientSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDuration: Int
    @Binding var selectedAudioSourceId: String

    @State private var isPreviewPlaying = false
    @State private var showingMediaPicker = false
    @State private var showingDocumentPicker = false
    @State private var importedSources: [ImportedAudioSource] = ImportedAudioStore.shared.sources
    @State private var importError: String?
    @State private var affirmationsEnabled = SettingsManager.shared.isAmbientAffirmationsEnabled

    private let previewController = MusicController()
    private let mediaLibraryController = MediaLibraryController()
    private let documentPickerController = DocumentPickerController()
    private let durationOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            List {
                Section("Duration") {
                    Picker("Session Length", selection: $selectedDuration) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .onChange(of: selectedDuration) { _, newValue in
                        SettingsManager.shared.ambientDuration = newValue
                    }
                }

                Section("Bundled Music") {
                    ForEach(BundledAudioSource.musicTracks, id: \.id) { track in
                        audioTrackRow(
                            id: track.id,
                            name: track.displayName,
                            icon: "music.note",
                            previewAction: {
                                await previewController.startPlayback(trackName: track.fileName)
                            }
                        )
                    }
                }

                // Imported audio section
                if !importedSources.isEmpty {
                    Section("Your Music") {
                        ForEach(importedSources, id: \.id) { source in
                            audioTrackRow(
                                id: source.id,
                                name: source.displayName,
                                icon: "doc.fill",
                                previewAction: nil
                            )
                        }
                        .onDelete(perform: deleteImportedSources)
                    }
                }

                // Affirmations section
                Section {
                    Toggle("Affirmations", isOn: $affirmationsEnabled)
                        .onChange(of: affirmationsEnabled) { _, newValue in
                            SettingsManager.shared.isAmbientAffirmationsEnabled = newValue
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

                // Import section
                Section {
                    Button {
                        Task {
                            let authorized = await mediaLibraryController.requestAuthorization()
                            if authorized {
                                showingMediaPicker = true
                            } else {
                                importError = "Please allow access to Apple Music in Settings"
                            }
                        }
                    } label: {
                        Label("Choose from Music Library", systemImage: "music.note.list")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Import from Files", systemImage: "folder")
                    }
                } header: {
                    Text("Import")
                } footer: {
                    if let error = importError {
                        Text(error)
                            .foregroundStyle(.red)
                    } else {
                        Text("Add your own music for ambient sessions")
                    }
                }
            }
            .navigationTitle("Ambient Music")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await previewController.fadeOutAndStop(duration: 1.0)
                        }
                        dismiss()
                    }
                }
            }
            .onDisappear {
                Task {
                    await previewController.fadeOutAndStop(duration: 1.0)
                }
            }
            .sheet(isPresented: $showingMediaPicker) {
                MediaLibraryPickerView { mediaItem in
                    handleMediaSelection(mediaItem)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    Task {
                        await handleDocumentSelection(url)
                    }
                }
            }
        }
    }

    private func audioTrackRow(id: String, name: String, icon: String, previewAction: (() async -> Void)?) -> some View {
        HStack {
            Button {
                selectedAudioSourceId = id
                SettingsManager.shared.ambientAudioSourceId = id
            } label: {
                HStack {
                    Image(systemName: selectedAudioSourceId == id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedAudioSourceId == id ? .cyan : .secondary)
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(name)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if let previewAction = previewAction {
                Button {
                    Task {
                        if isPreviewPlaying && selectedAudioSourceId == id {
                            await previewController.fadeOutAndStop(duration: 2.0)
                            isPreviewPlaying = false
                        } else {
                            await previewAction()
                            selectedAudioSourceId = id
                            isPreviewPlaying = true
                        }
                    }
                } label: {
                    Image(systemName: isPreviewPlaying && selectedAudioSourceId == id ? "stop.fill" : "play.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleMediaSelection(_ mediaItem: MPMediaItem) {
        guard let source = mediaLibraryController.createAudioSource(from: mediaItem) else {
            importError = "Cannot use this track (may be DRM-protected)"
            return
        }

        selectedAudioSourceId = source.id
        SettingsManager.shared.ambientAudioSourceId = source.id
        importError = nil
    }

    private func handleDocumentSelection(_ url: URL) async {
        do {
            let source = try await documentPickerController.importAudioFile(from: url)
            ImportedAudioStore.shared.add(source)
            importedSources = ImportedAudioStore.shared.sources
            selectedAudioSourceId = source.id
            SettingsManager.shared.ambientAudioSourceId = source.id
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    private func deleteImportedSources(at offsets: IndexSet) {
        for index in offsets {
            let source = importedSources[index]
            try? documentPickerController.removeImportedFile(source)
            ImportedAudioStore.shared.remove(id: source.id)
        }
        importedSources = ImportedAudioStore.shared.sources

        // Reset to default if deleted current selection
        if !BundledAudioSource.musicTracks.contains(where: { $0.id == selectedAudioSourceId }) &&
           !importedSources.contains(where: { $0.id == selectedAudioSourceId }) {
            selectedAudioSourceId = "inner-stillness"
            SettingsManager.shared.ambientAudioSourceId = "inner-stillness"
        }
    }
}

// MARK: - Guided Settings View

/// Settings view for guided meditation selection.
struct GuidedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAudioSourceId: String

    @State private var isPreviewPlaying = false
    @State private var showingMediaPicker = false
    @State private var showingDocumentPicker = false
    @State private var importedSources: [ImportedAudioSource] = ImportedAudioStore.shared.sources
    @State private var importError: String?

    private let previewController = MusicController()
    private let mediaLibraryController = MediaLibraryController()
    private let documentPickerController = DocumentPickerController()

    var body: some View {
        NavigationStack {
            List {
                // Bundled meditations section
                if !BundledAudioSource.meditations.isEmpty {
                    Section("Bundled Meditations") {
                        ForEach(BundledAudioSource.meditations, id: \.id) { meditation in
                            audioSourceRow(
                                id: meditation.id,
                                name: meditation.displayName,
                                duration: meditation.duration,
                                icon: "leaf.fill"
                            )
                        }
                    }
                }

                // Imported audio section
                if !importedSources.isEmpty {
                    Section("Your Audio") {
                        ForEach(importedSources, id: \.id) { source in
                            audioSourceRow(
                                id: source.id,
                                name: source.displayName,
                                duration: source.duration,
                                icon: "doc.fill"
                            )
                        }
                        .onDelete(perform: deleteImportedSources)
                    }
                }

                // Import section
                Section {
                    Button {
                        Task {
                            let authorized = await mediaLibraryController.requestAuthorization()
                            if authorized {
                                showingMediaPicker = true
                            } else {
                                importError = "Please allow access to Apple Music in Settings"
                            }
                        }
                    } label: {
                        Label("Choose from Music Library", systemImage: "music.note.list")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Import from Files", systemImage: "folder")
                    }
                } header: {
                    Text("Import")
                } footer: {
                    if let error = importError {
                        Text(error)
                            .foregroundStyle(.red)
                    } else {
                        Text("Import your own guided meditations from Apple Music or Files")
                    }
                }
            }
            .navigationTitle("Guided Meditation")
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
            .sheet(isPresented: $showingMediaPicker) {
                MediaLibraryPickerView { mediaItem in
                    handleMediaSelection(mediaItem)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    Task {
                        await handleDocumentSelection(url)
                    }
                }
            }
        }
    }

    private func audioSourceRow(id: String, name: String, duration: TimeInterval?, icon: String) -> some View {
        HStack {
            Button {
                selectedAudioSourceId = id
                SettingsManager.shared.guidedAudioSourceId = id
            } label: {
                HStack {
                    Image(systemName: selectedAudioSourceId == id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedAudioSourceId == id ? .cyan : .secondary)
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading) {
                        Text(name)
                            .foregroundStyle(.primary)
                        if let duration = duration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func handleMediaSelection(_ mediaItem: MPMediaItem) {
        guard let source = mediaLibraryController.createAudioSource(from: mediaItem) else {
            importError = "Cannot use this track (may be DRM-protected)"
            return
        }

        // For library sources, we don't need to import - just store the reference
        // Note: Library sources use persistentID to find the track at playback time
        selectedAudioSourceId = source.id
        SettingsManager.shared.guidedAudioSourceId = source.id
        importError = nil
    }

    private func handleDocumentSelection(_ url: URL) async {
        do {
            let source = try await documentPickerController.importAudioFile(from: url)
            ImportedAudioStore.shared.add(source)
            importedSources = ImportedAudioStore.shared.sources
            selectedAudioSourceId = source.id
            SettingsManager.shared.guidedAudioSourceId = source.id
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    private func deleteImportedSources(at offsets: IndexSet) {
        for index in offsets {
            let source = importedSources[index]
            try? documentPickerController.removeImportedFile(source)
            ImportedAudioStore.shared.remove(id: source.id)
        }
        importedSources = ImportedAudioStore.shared.sources

        // Reset to default if deleted track was selected
        if !BundledAudioSource.meditations.contains(where: { $0.id == selectedAudioSourceId }) &&
           !importedSources.contains(where: { $0.id == selectedAudioSourceId }) {
            selectedAudioSourceId = "morning-light"
            SettingsManager.shared.guidedAudioSourceId = "morning-light"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

#Preview("Ambient Settings") {
    @Previewable @State var duration = 10
    @Previewable @State var audioSourceId = "inner-stillness"

    AmbientSettingsView(
        selectedDuration: $duration,
        selectedAudioSourceId: $audioSourceId
    )
}

#Preview("Guided Settings") {
    @Previewable @State var audioSourceId = "morning-light"

    GuidedSettingsView(
        selectedAudioSourceId: $audioSourceId
    )
}

#Preview("Start View") {
    @Previewable @State var sessionType: SessionType = .breathe
    @Previewable @State var duration = 5
    @Previewable @State var inhale = 4
    @Previewable @State var exhale = 8
    @Previewable @State var ambientDuration = 10
    @Previewable @State var ambientAudioSourceId = "inner-stillness"
    @Previewable @State var guidedAudioSourceId = "morning-light"

    StartView(
        selectedSessionType: $sessionType,
        selectedDuration: $duration,
        selectedInhale: $inhale,
        selectedExhale: $exhale,
        onStartBreathing: {},
        ambientDuration: $ambientDuration,
        ambientAudioSourceId: $ambientAudioSourceId,
        onStartAmbient: {},
        guidedAudioSourceId: $guidedAudioSourceId,
        onStartGuided: {}
    )
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
