import Foundation
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "ImportedAudioStore")

/// Persists references to user-imported audio files.
public final class ImportedAudioStore: @unchecked Sendable {
    public static let shared = ImportedAudioStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "importedAudioSources"

    private var _sources: [ImportedAudioSource] = []

    /// All imported audio sources.
    public var sources: [ImportedAudioSource] {
        _sources
    }

    private init() {
        loadFromDisk()
    }

    /// Adds an imported audio source.
    public func add(_ source: ImportedAudioSource) {
        _sources.append(source)
        saveToDisk()
        logger.info("Added imported audio: \(source.displayName)")
    }

    /// Removes an imported audio source by ID.
    public func remove(id: String) {
        _sources.removeAll { $0.id == id }
        saveToDisk()
        logger.info("Removed imported audio with id: \(id)")
    }

    /// Finds an imported audio source by ID.
    public func find(id: String) -> ImportedAudioSource? {
        _sources.first { $0.id == id }
    }

    /// Clears all imported audio sources and their files.
    public func clearAll() {
        let documentPicker = DocumentPickerController()
        for source in _sources {
            try? documentPicker.removeImportedFile(source)
        }
        _sources.removeAll()
        saveToDisk()
        logger.info("Cleared all imported audio")
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: storageKey) else {
            logger.info("No stored imported audio sources found")
            return
        }

        do {
            self._sources = try JSONDecoder().decode([ImportedAudioSource].self, from: data)
            logger.info("Loaded \(self._sources.count) imported audio sources")

            // Verify files still exist
            self._sources = self._sources.filter { source in
                if let url = source.getURL(), FileManager.default.fileExists(atPath: url.path) {
                    return true
                }
                logger.warning("Imported file no longer exists: \(source.fileName)")
                return false
            }
        } catch {
            logger.error("Failed to decode imported audio sources: \(error.localizedDescription)")
            _sources = []
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(_sources)
            defaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to encode imported audio sources: \(error.localizedDescription)")
        }
    }
}
