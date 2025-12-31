import SwiftUI

/// View displayed during an active ambient music session.
struct AmbientSessionView: View {
    @Bindable var viewModel: AmbientMusicViewModel
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

            // Large timer display
            Text(formattedTime)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())

            // Progress bar
            ProgressView(value: viewModel.playbackState.progress)
                .progressViewStyle(.linear)
                .tint(accentCyan)
                .padding(.horizontal, 60)

            // Remaining time
            Text("\(formattedRemainingTime) remaining")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            // Show affirmation if enabled, otherwise show track name
            Group {
                if let affirmation = viewModel.currentAffirmation {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(accentCyan)
                        Text(affirmation)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.9))
                                .combined(with: .offset(y: 15)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.9))
                                .combined(with: .offset(y: -15))
                        )
                    )
                    .id(affirmation)
                } else if let trackName = viewModel.currentTrackName,
                          !SettingsManager.shared.isAmbientAffirmationsEnabled {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(accentCyan)
                        Text(trackName)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: viewModel.currentAffirmation)

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

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(accentCyan)

            Text("Session Complete")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("\(viewModel.selectedDuration) \(viewModel.selectedDuration == 1 ? "minute" : "minutes") of music")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))

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

    private var formattedTime: String {
        let minutes = viewModel.elapsedSeconds / 60
        let seconds = viewModel.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedRemainingTime: String {
        let remaining = max(0, viewModel.totalSeconds - viewModel.elapsedSeconds)
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

#Preview("Playing") {
    let viewModel = AmbientMusicViewModel()

    AmbientSessionView(viewModel: viewModel) {}
        .task {
            await viewModel.startSession()
        }
}

#Preview("Completed") {
    let viewModel = AmbientMusicViewModel()

    AmbientSessionView(viewModel: viewModel) {}
        .onAppear {
            // Manually set to completed for preview
        }
}
