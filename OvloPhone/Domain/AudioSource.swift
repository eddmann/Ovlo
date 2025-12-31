import Foundation

// MARK: - Audio Configuration

/// Entry in the audio configuration JSON files.
public struct AudioConfigEntry: Codable, Sendable {
    public let id: String
    public let title: String
}

/// Loads audio configuration from JSON files in the bundle.
public enum AudioConfigLoader {
    /// Load chime entries from chimes.json
    public static func loadChimes() -> [AudioConfigEntry] {
        load(fileName: "chimes")
    }

    /// Load music track entries from music.json
    public static func loadMusicTracks() -> [AudioConfigEntry] {
        load(fileName: "music")
    }

    /// Load meditation entries from meditations.json
    public static func loadMeditations() -> [AudioConfigEntry] {
        load(fileName: "meditations")
    }

    private static func load(fileName: String) -> [AudioConfigEntry] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([AudioConfigEntry].self, from: data) else {
            print("Warning: Could not load \(fileName).json from bundle")
            return []
        }
        return entries
    }
}

/// The origin type of an audio source.
public enum AudioSourceType: String, Codable, Sendable {
    case bundled
    case musicLibrary
    case imported
}

/// A playable audio source for meditation sessions.
public protocol AudioSource: Identifiable {
    var id: String { get }
    var displayName: String { get }
    var duration: TimeInterval? { get }
    var sourceType: AudioSourceType { get }
    func getURL() -> URL?
}

/// Audio bundled with the app (music tracks or guided meditations).
public struct BundledAudioSource: AudioSource, Codable, Equatable {
    public let id: String
    public let displayName: String
    public let fileName: String
    public let fileExtension: String
    public let duration: TimeInterval?
    public let sourceType: AudioSourceType = .bundled
    public let category: BundledCategory

    public enum BundledCategory: String, Codable, Sendable {
        case music
        case meditation
    }

    public init(
        id: String,
        displayName: String,
        fileName: String,
        fileExtension: String = "mp3",
        duration: TimeInterval? = nil,
        category: BundledCategory
    ) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.duration = duration
        self.category = category
    }

    public func getURL() -> URL? {
        // Resources are copied to the bundle root, not in subdirectories
        return Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    }
}

/// Audio from the user's Apple Music/iTunes library.
public struct LibraryAudioSource: AudioSource, Codable, Equatable {
    public let id: String
    public let displayName: String
    public let artist: String?
    public let duration: TimeInterval?
    public let persistentID: UInt64
    public let sourceType: AudioSourceType = .musicLibrary

    public init(
        id: String,
        displayName: String,
        artist: String?,
        duration: TimeInterval?,
        persistentID: UInt64
    ) {
        self.id = id
        self.displayName = displayName
        self.artist = artist
        self.duration = duration
        self.persistentID = persistentID
    }

    public func getURL() -> URL? {
        // URL is retrieved at playback time via MPMediaItem
        nil
    }
}

/// Audio imported from the Files app.
public struct ImportedAudioSource: AudioSource, Codable, Equatable {
    public let id: String
    public let displayName: String
    public let fileName: String
    public let duration: TimeInterval?
    public let importedDate: Date
    public let sourceType: AudioSourceType = .imported

    public init(
        id: String,
        displayName: String,
        fileName: String,
        duration: TimeInterval?,
        importedDate: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.duration = duration
        self.importedDate = importedDate
    }

    public func getURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("ImportedAudio").appendingPathComponent(fileName)
    }
}

/// Type-erased wrapper for storing any audio source.
public struct AnyAudioSource: AudioSource, Codable, Equatable {
    public let id: String
    public let displayName: String
    public let duration: TimeInterval?
    public let sourceType: AudioSourceType

    private let _getURL: () -> URL?

    public init<T: AudioSource>(_ source: T) {
        self.id = source.id
        self.displayName = source.displayName
        self.duration = source.duration
        self.sourceType = source.sourceType
        self._getURL = source.getURL
    }

    public func getURL() -> URL? {
        _getURL()
    }

    // Codable conformance for the wrapper
    enum CodingKeys: String, CodingKey {
        case id, displayName, duration, sourceType
        case bundled, library, imported
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.sourceType = try container.decode(AudioSourceType.self, forKey: .sourceType)

        switch sourceType {
        case .bundled:
            let source = try container.decode(BundledAudioSource.self, forKey: .bundled)
            self._getURL = source.getURL
        case .musicLibrary:
            let source = try container.decode(LibraryAudioSource.self, forKey: .library)
            self._getURL = source.getURL
        case .imported:
            let source = try container.decode(ImportedAudioSource.self, forKey: .imported)
            self._getURL = source.getURL
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(sourceType, forKey: .sourceType)
    }

    public static func == (lhs: AnyAudioSource, rhs: AnyAudioSource) -> Bool {
        lhs.id == rhs.id && lhs.sourceType == rhs.sourceType
    }
}

// MARK: - Bundled Audio Catalogs

public extension BundledAudioSource {
    /// All bundled chimes available for breathing sessions.
    /// Loaded from chimes.json - first entry is the default.
    static let chimes: [BundledAudioSource] = {
        AudioConfigLoader.loadChimes().map { entry in
            BundledAudioSource(
                id: entry.id,
                displayName: entry.title,
                fileName: entry.id,
                category: .music  // Chimes use music category for playback
            )
        }
    }()

    /// All bundled music tracks available for ambient sessions.
    /// Loaded from music.json - first entry is the default.
    static let musicTracks: [BundledAudioSource] = {
        AudioConfigLoader.loadMusicTracks().map { entry in
            BundledAudioSource(
                id: entry.id,
                displayName: entry.title,
                fileName: entry.id,
                category: .music
            )
        }
    }()

    /// Bundled guided meditation tracks.
    /// Loaded from meditations.json - first entry is the default.
    static let meditations: [BundledAudioSource] = {
        AudioConfigLoader.loadMeditations().map { entry in
            BundledAudioSource(
                id: entry.id,
                displayName: entry.title,
                fileName: entry.id,
                category: .meditation
            )
        }
    }()
}
