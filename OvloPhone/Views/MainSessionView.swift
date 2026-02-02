import SwiftUI

/// Main view that coordinates between session types.
///
/// Shows the start screen with session type tabs when no session is active,
/// and switches to the appropriate session view when a session starts.
struct MainSessionView: View {
    @State var breathingViewModel: BreathingViewModel
    @State var ambientViewModel: AmbientMusicViewModel
    @State var guidedViewModel: GuidedMeditationViewModel

    #if DEBUG
    var demoSessionType: SessionType?
    @State private var hasAppliedDemoMode = false
    #endif

    @State private var selectedSessionType: SessionType = SettingsManager.shared.selectedSessionType
    @State private var activeSession: ActiveSession = .none

    private enum ActiveSession {
        case none
        case breathing
        case ambient
        case guided
    }

    var body: some View {
        Group {
            switch activeSession {
            case .none:
                startView
            case .breathing:
                BreathingView(viewModel: breathingViewModel, onReturn: returnToStart)
            case .ambient:
                AmbientSessionView(viewModel: ambientViewModel, onDismiss: returnToStart)
            case .guided:
                GuidedSessionView(viewModel: guidedViewModel, onDismiss: returnToStart)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeSession)
        #if DEBUG
        .onAppear {
            applyDemoModeIfNeeded()
        }
        #endif
    }

    #if DEBUG
    // MARK: - Demo Mode

    private func applyDemoModeIfNeeded() {
        guard !hasAppliedDemoMode, let sessionType = demoSessionType else { return }
        hasAppliedDemoMode = true

        switch sessionType {
        case .breathe:
            startBreathingSession()
        case .ambient:
            startAmbientSession()
        case .guided:
            startGuidedSession()
        }
    }
    #endif

    // MARK: - Start View

    private var startView: some View {
        StartView(
            selectedSessionType: $selectedSessionType,
            selectedDuration: $breathingViewModel.selectedDuration,
            selectedInhale: $breathingViewModel.selectedInhale,
            selectedExhale: $breathingViewModel.selectedExhale,
            onStartBreathing: startBreathingSession,
            ambientDuration: $ambientViewModel.selectedDuration,
            ambientAudioSourceId: $ambientViewModel.selectedAudioSourceId,
            onStartAmbient: startAmbientSession,
            guidedAudioSourceId: $guidedViewModel.selectedAudioSourceId,
            onStartGuided: startGuidedSession
        )
    }

    // MARK: - Actions

    private func startBreathingSession() {
        activeSession = .breathing
        Task {
            await breathingViewModel.startLocalSession()
        }
    }

    private func startAmbientSession() {
        activeSession = .ambient
        Task {
            await ambientViewModel.startSession()
        }
    }

    private func startGuidedSession() {
        activeSession = .guided
        Task {
            await guidedViewModel.startSession()
        }
    }

    private func returnToStart() {
        activeSession = .none
    }
}

#Preview {
    let engine = BreathingEngine()
    let breathingVM = BreathingViewModel(engine: engine)
    let ambientVM = AmbientMusicViewModel()
    let guidedVM = GuidedMeditationViewModel()

    #if DEBUG
    MainSessionView(
        breathingViewModel: breathingVM,
        ambientViewModel: ambientVM,
        guidedViewModel: guidedVM,
        demoSessionType: nil
    )
    #else
    MainSessionView(
        breathingViewModel: breathingVM,
        ambientViewModel: ambientVM,
        guidedViewModel: guidedVM
    )
    #endif
}
