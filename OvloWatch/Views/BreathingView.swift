import SwiftUI

/// Main view for the watchOS breathing exercise interface.
///
/// Displays either:
/// - Start screen with duration picker (when ready)
/// - Breathing animation with progress and controls (when active/completed)
///
/// Supports both local watch-initiated sessions and remote iOS commands.
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
            let circleSize = minDimension * 0.65
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

                Spacer(minLength: viewModel.currentState.isActive ? 35 : nil)

                Text(viewModel.currentState.displayText)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(labelColor)
                    .animation(.easeInOut, value: viewModel.currentState)

                Spacer()

                if viewModel.currentState == .completed {
                    Button(action: returnToStart) {
                        Text("Done")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
        engine: BreathingEngine(),
        connectivity: WatchConnectivityManager()
    )

    BreathingView(viewModel: viewModel)
}
