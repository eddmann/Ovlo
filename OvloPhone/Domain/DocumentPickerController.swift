import Foundation
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "DocumentPickerController")

/// Controller for importing audio files from the Files app.
public final class DocumentPickerController: @unchecked Sendable {

    /// Supported audio file types for import.
    public static let supportedTypes: [UTType] = [
        .audio,
        .mp3,
        .wav,
        .aiff,
        .mpeg4Audio  // m4a
    ]

    /// Directory where imported audio files are stored.
    private var importDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("ImportedAudio", isDirectory: true)
    }

    public init() {
        createImportDirectoryIfNeeded()
    }

    private func createImportDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create import directory: \(error.localizedDescription)")
        }
    }

    /// Imports an audio file from a security-scoped URL.
    /// - Parameters:
    ///   - url: The URL from the document picker (security-scoped)
    ///   - displayName: Optional display name (defaults to filename without extension)
    /// - Returns: An ImportedAudioSource for the copied file
    /// - Throws: If the file cannot be accessed or copied
    public func importAudioFile(from url: URL, displayName: String? = nil) async throws -> ImportedAudioSource {
        // Start security-scoped access
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // Generate unique filename
        let originalName = url.lastPathComponent
        let uniqueName = generateUniqueFilename(for: originalName)
        let destinationURL = importDirectory.appendingPathComponent(uniqueName)

        // Copy file to app storage
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            logger.info("Imported audio file: \(uniqueName)")
        } catch {
            logger.error("Failed to copy file: \(error.localizedDescription)")
            throw ImportError.copyFailed(error)
        }

        // Get duration
        let duration = await getDuration(for: destinationURL)

        // Create audio source
        let name = displayName ?? url.deletingPathExtension().lastPathComponent
        return ImportedAudioSource(
            id: "imported-\(UUID().uuidString)",
            displayName: name,
            fileName: uniqueName,
            duration: duration,
            importedDate: Date()
        )
    }

    /// Removes an imported audio file.
    /// - Parameter source: The imported audio source to remove
    /// - Throws: If the file cannot be deleted
    public func removeImportedFile(_ source: ImportedAudioSource) throws {
        guard let url = source.getURL() else {
            throw ImportError.fileNotFound
        }

        try FileManager.default.removeItem(at: url)
        logger.info("Removed imported file: \(source.fileName)")
    }

    /// Lists all imported audio files.
    /// - Returns: URLs of all files in the import directory
    public func listImportedFiles() -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: importDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            return contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2  // Most recent first
            }
        } catch {
            logger.error("Failed to list imported files: \(error.localizedDescription)")
            return []
        }
    }

    /// Gets the total size of imported files.
    /// - Returns: Total size in bytes
    public func totalImportedSize() -> UInt64 {
        var total: UInt64 = 0
        for url in listImportedFiles() {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }

    // MARK: - Private Helpers

    private func generateUniqueFilename(for originalName: String) -> String {
        var name = originalName
        var counter = 1

        while FileManager.default.fileExists(atPath: importDirectory.appendingPathComponent(name).path) {
            let baseName = (originalName as NSString).deletingPathExtension
            let ext = (originalName as NSString).pathExtension
            name = "\(baseName)-\(counter).\(ext)"
            counter += 1
        }

        return name
    }

    private func getDuration(for url: URL) async -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            logger.warning("Could not get duration for \(url.lastPathComponent)")
            return nil
        }
    }
}

// MARK: - Errors

public enum ImportError: LocalizedError {
    case accessDenied
    case copyFailed(Error)
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Could not access the selected file"
        case .copyFailed(let error):
            return "Failed to import file: \(error.localizedDescription)"
        case .fileNotFound:
            return "The imported file could not be found"
        }
    }
}

// Import AVFoundation for duration detection
import AVFoundation
