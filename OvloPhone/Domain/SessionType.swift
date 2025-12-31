import Foundation

/// The type of meditation session available in the app.
public enum SessionType: String, CaseIterable, Identifiable, Sendable {
    case breathe = "Breathe"
    case guided = "Guided"
    case ambient = "Music"

    public var id: String { rawValue }
}
