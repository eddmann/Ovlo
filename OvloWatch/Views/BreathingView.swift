import SwiftUI

/// Main view for the watchOS breathing exercise interface.
///
/// Displays either:
/// - Start screen with duration picker (when ready)
/// - Breathing animation with progress and controls (when active/completed)
struct BreathingView: View {
    @State private var viewModel: BreathingViewModel

    private let accentCyan = Color(red: 0.25, green: 0.95, blue: 0.88)

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
        Group {
            if viewModel.currentState == .completed {
                completionView
            } else {
                activeSessionView
            }
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

    private var activeSessionView: some View {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 40))
                .foregroundStyle(accentCyan)

            Text("Session Complete")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("\(viewModel.totalSeconds / 60) \(viewModel.totalSeconds / 60 == 1 ? "min" : "mins")")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Button(action: returnToStart) {
                Text("Done")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(accentCyan)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
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
        engine: BreathingEngine()
    )

    BreathingView(viewModel: viewModel)
}
