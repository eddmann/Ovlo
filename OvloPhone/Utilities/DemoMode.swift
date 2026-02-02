#if DEBUG
import Foundation

/// Demo modes for App Store screenshots and testing.
/// Launch with `--demo <mode>` to activate.
enum DemoMode: String, CaseIterable {
    case startView
    case breathingActive
    case breathingAffirmation
    case ambientActive
    case guidedActive

    static func fromArguments() -> DemoMode? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--demo"),
              index + 1 < args.count else {
            return nil
        }
        return DemoMode(rawValue: args[index + 1])
    }

    var description: String {
        switch self {
        case .startView: "Session selection screen"
        case .breathingActive: "Breathing session mid-inhale"
        case .breathingAffirmation: "Breathing with affirmation visible"
        case .ambientActive: "Ambient music session in progress"
        case .guidedActive: "Guided meditation session in progress"
        }
    }
}
#endif
