import SwiftUI

/// View for the iOS breathing exercise interface.
///
/// Displays the breathing animation with progress and controls during an active session.
struct BreathingView: View {
    @Bindable var viewModel: BreathingViewModel
    let onReturn: () -> Void

    private let accentCyan = Color(red: 0.25, green: 0.95, blue: 0.88)

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

            if viewModel.currentState == .completed {
                completionView
            } else {
                activeSessionView
            }
        }
        .animation(.easeInOut, value: viewModel.currentState)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if viewModel.currentState.isActive && value.translation.height < -50 {
                        returnToStart()
                    }
                }
        )
    }

    // MARK: - Subviews

    private var activeSessionView: some View {
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
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: geometry.size.width * 0.8, minHeight: 60, maxHeight: 60, alignment: .center)
                        .scaleEffect(textScale)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.5), value: affirmation)
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

                if viewModel.currentState.isActive {
                    // Swipe hint
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                        Text("Swipe up to stop")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 80))
                .foregroundStyle(accentCyan)

            Text("Session Complete")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("\(viewModel.totalSeconds / 60) \(viewModel.totalSeconds / 60 == 1 ? "minute" : "minutes") of breathing")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Button(action: returnToStart) {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.18))
                    .frame(width: 120, height: 50)
                    .background(
                        Capsule()
                            .fill(accentCyan)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Actions

    private func returnToStart() {
        Task {
            await viewModel.stopSession()
            onReturn()
        }
    }
}

#Preview {
    let viewModel = BreathingViewModel(
        engine: BreathingEngine()
    )

    BreathingView(viewModel: viewModel) {}
}
