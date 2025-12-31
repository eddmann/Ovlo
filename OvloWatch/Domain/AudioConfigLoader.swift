import Foundation

/// Entry in the audio configuration JSON files.
public struct AudioConfigEntry: Codable, Sendable {
    public let id: String
    public let title: String
}

/// Loads audio configuration from JSON files in the bundle.
public enum AudioConfigLoader {
    /// Load chime entries from chimes.json
    public static func loadChimes() -> [AudioConfigEntry] {
        guard let url = Bundle.main.url(forResource: "chimes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([AudioConfigEntry].self, from: data) else {
            print("Warning: Could not load chimes.json from bundle")
            return []
        }
        return entries
    }

    /// Cached chimes loaded at first access.
    public static let chimes: [AudioConfigEntry] = loadChimes()

    /// Default chime ID (first entry in chimes.json).
    public static var defaultChimeId: String {
        chimes.first?.id ?? "tibetan-bell"
    }
}
