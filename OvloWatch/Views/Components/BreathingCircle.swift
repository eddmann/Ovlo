import SwiftUI

/// Animated circle that expands and contracts with breathing phases.
///
/// The circle scales from 1.0 (normal) to 1.5 (expanded) based on the
/// breathing progress. It uses smooth easing for a natural breathing feel.
/// Optionally displays a progress arc that scales with the breathing animation.
struct BreathingCircle: View {
    let state: BreathingState
    var size: CGFloat = 100
    var elapsedSeconds: Int? = nil
    var totalSeconds: Int? = nil
    var inhaleDuration: TimeInterval = 4.0
    var exhaleDuration: TimeInterval = 8.0

    /// Whether to show progress indicators
    private var showProgress: Bool {
        elapsedSeconds != nil && totalSeconds != nil && totalSeconds! > 0
    }

    /// Session progress as a fraction from 0.0 to 1.0
    private var sessionProgress: Double {
        guard let elapsed = elapsedSeconds, let total = totalSeconds, total > 0 else {
            return 0.0
        }
        return min(Double(elapsed) / Double(total), 1.0)
    }

    private var scale: CGFloat {
        switch state {
        case .ready, .completed:
            return 1.0
        case .inhaling(let progress):
            return 1.0 + (0.5 * progress)
        case .exhaling(let progress):
            return 1.5 - (0.5 * progress)
        }
    }

    private var opacity: Double {
        switch state {
        case .ready:
            return 0.6
        case .inhaling, .exhaling:
            return 0.8
        case .completed:
            return 1.0
        }
    }

    private var color: Color {
        switch state {
        case .ready:
            return .gray
        case .inhaling:
            return .blue
        case .exhaling:
            return .cyan
        case .completed:
            return .green
        }
    }

    private var phaseDuration: TimeInterval {
        switch state {
        case .inhaling:
            return inhaleDuration
        case .exhaling:
            return exhaleDuration
        default:
            return 0.0
        }
    }

    private var remainingPhaseSeconds: Int {
        let remaining = (1.0 - state.progress) * phaseDuration
        return max(1, Int(ceil(remaining)))
    }

    private var innerCircleSize: CGFloat {
        showProgress ? size * 0.9 : size
    }

    private var progressLineWidth: CGFloat {
        size * 0.025
    }

    var body: some View {
        ZStack {
            if showProgress {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: progressLineWidth)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 0.3), value: state)
            }

            if showProgress {
                Circle()
                    .trim(from: 0, to: sessionProgress)
                    .stroke(
                        color.opacity(0.8),
                        style: StrokeStyle(lineWidth: progressLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 0.3), value: state)
                    .animation(.linear(duration: 0.5), value: sessionProgress)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.8), color.opacity(0.4)],
                        center: .center,
                        startRadius: innerCircleSize * 0.17,
                        endRadius: innerCircleSize * 0.67
                    )
                )
                .frame(width: innerCircleSize, height: innerCircleSize)
                .scaleEffect(scale)
                .opacity(opacity)
                .animation(.easeInOut(duration: 0.3), value: state)

            if state.isActive {
                Text("\(remainingPhaseSeconds)")
                    .font(.system(size: size * 0.25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: remainingPhaseSeconds)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        BreathingCircle(state: .ready, size: 80)
        BreathingCircle(
            state: .inhaling(progress: 0.5),
            size: 100,
            elapsedSeconds: 45,
            totalSeconds: 120
        )
        BreathingCircle(
            state: .exhaling(progress: 0.5),
            size: 100,
            elapsedSeconds: 90,
            totalSeconds: 120
        )
        BreathingCircle(state: .completed, size: 80)
    }
}
