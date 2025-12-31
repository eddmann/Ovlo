import SwiftUI

/// View displayed during an active guided meditation session.
struct GuidedSessionView: View {
    @Bindable var viewModel: GuidedMeditationViewModel
    let onDismiss: () -> Void

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

            if viewModel.playbackState == .completed {
                completionView
            } else {
                activeSessionView
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if viewModel.playbackState.isPlaying && value.translation.height < -50 {
                        Task {
                            await viewModel.stopSession()
                            onDismiss()
                        }
                    }
                }
        )
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: viewModel.playbackState.progress)
                    .stroke(accentCyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: viewModel.playbackState.progress)

                VStack(spacing: 4) {
                    Text(formattedElapsedTime)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    if viewModel.totalSeconds > 0 {
                        Text("of \(formattedTotalTime)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            Spacer()

            // Meditation name
            if let name = viewModel.currentMeditationName {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(accentCyan)
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            }

            Spacer()

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

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(accentCyan)

            Text("Meditation Complete")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            if let name = viewModel.currentMeditationName {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if viewModel.totalSeconds > 0 {
                Text(formattedTotalTime)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
                viewModel.dismissCompletion()
                onDismiss()
            } label: {
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

    // MARK: - Helpers

    private var formattedElapsedTime: String {
        let minutes = viewModel.elapsedSeconds / 60
        let seconds = viewModel.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTotalTime: String {
        let minutes = viewModel.totalSeconds / 60
        let seconds = viewModel.totalSeconds % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Playing") {
    let viewModel = GuidedMeditationViewModel()

    GuidedSessionView(viewModel: viewModel) {}
}

#Preview("Completed") {
    let viewModel = GuidedMeditationViewModel()

    GuidedSessionView(viewModel: viewModel) {}
}
