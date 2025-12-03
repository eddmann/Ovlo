import SwiftUI

/// Main view for the iOS breathing exercise interface.
///
/// Displays either:
/// - Start screen with duration picker (when ready)
/// - Breathing animation with progress and controls (when active/completed)
struct BreathingView: View {
    @State private var viewModel: BreathingViewModel

    init(viewModel: BreathingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.currentState == .ready {
                StartView(
                    selectedDuration: $viewModel.selectedDuration,
                    selectedInhale: $viewModel.selectedInhale,
                    selectedExhale: $viewModel.selectedExhale,
                    onStart: startLocalSession
                )
                .transition(.opacity)
            } else {
                breathingInterfaceView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.currentState)
    }

    // MARK: - Subviews

    private var breathingInterfaceView: some View {
        GeometryReader { geometry in
            let minDimension = min(geometry.size.width, geometry.size.height)
            let circleSize = minDimension * 0.45
            let spacing = geometry.size.height * 0.02

            VStack(spacing: spacing) {
                Spacer()

                BreathingCircle(
                    state: viewModel.currentState,
                    size: circleSize,
                    elapsedSeconds: viewModel.currentState.isActive ? viewModel.elapsedSeconds : nil,
                    totalSeconds: viewModel.currentState.isActive ? viewModel.totalSeconds : nil,
                    inhaleDuration: viewModel.currentInhaleDuration,
                    exhaleDuration: viewModel.currentExhaleDuration
                )

                Spacer()

                // Show affirmation instead of "Breathe In/Out" when affirmations are enabled
                if viewModel.currentState.isActive, let affirmation = viewModel.currentAffirmation {
                    Text(affirmation)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(labelColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: geometry.size.width * 0.8)
                        .scaleEffect(textScale)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentState)
                        .id(affirmation)
                } else {
                    Text(viewModel.currentState.displayText)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(labelColor)
                        .animation(.easeInOut, value: viewModel.currentState)
                }

                Spacer()

                if viewModel.currentState == .completed {
                    Button(action: returnToStart) {
                        Text("Done")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .cornerRadius(25)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.08, blue: 0.18),
                    Color(red: 0.04, green: 0.20, blue: 0.35),
                    Color(red: 0.05, green: 0.35, blue: 0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .gesture(
            viewModel.currentState.isActive ?
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.height < -50 {
                            completeEarly()
                        }
                    }
                : nil
        )
    }

    // MARK: - Computed Properties

    private var labelColor: Color {
        switch viewModel.currentState {
        case .ready:
            return .secondary
        case .inhaling:
            return .blue
        case .exhaling:
            return .cyan
        case .completed:
            return .green
        }
    }

    /// Scale factor for text that breathes with the circle (1.0 to 1.2)
    private var textScale: CGFloat {
        switch viewModel.currentState {
        case .ready, .completed:
            return 1.0
        case .inhaling(let progress):
            return 1.0 + (0.2 * progress)
        case .exhaling(let progress):
            return 1.2 - (0.2 * progress)
        }
    }

    // MARK: - Actions

    private func startLocalSession() {
        Task {
            await viewModel.startLocalSession()
        }
    }

    private func completeEarly() {
        Task {
            await viewModel.completeSessionEarly()
        }
    }

    private func returnToStart() {
        Task {
            await viewModel.stopSession()
        }
    }
}

#Preview {
    @Previewable @State var viewModel = BreathingViewModel(
        engine: BreathingEngine()
    )

    BreathingView(viewModel: viewModel)
}
