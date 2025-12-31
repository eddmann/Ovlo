import Foundation
import MediaPlayer
import os

private let logger = Logger(subsystem: "com.ovlo.phone", category: "MediaLibraryController")

/// Controller for accessing the user's Apple Music/iTunes library.
public final class MediaLibraryController: NSObject, @unchecked Sendable {

    /// Requests authorization to access the user's music library.
    /// - Returns: `true` if authorization was granted
    @MainActor
    public func requestAuthorization() async -> Bool {
        let status = MPMediaLibrary.authorizationStatus()

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Creates an audio source from a media item.
    /// - Parameter mediaItem: The MPMediaItem to convert
    /// - Returns: A LibraryAudioSource if the item has an accessible URL
    public func createAudioSource(from mediaItem: MPMediaItem) -> LibraryAudioSource? {
        // Check if we can access the asset URL (DRM-protected items may not have one)
        guard mediaItem.assetURL != nil else {
            logger.warning("Media item has no accessible URL (may be DRM-protected)")
            return nil
        }

        let id = "library-\(mediaItem.persistentID)"
        let title = mediaItem.title ?? "Unknown Track"
        let artist = mediaItem.artist

        return LibraryAudioSource(
            id: id,
            displayName: title,
            artist: artist,
            duration: mediaItem.playbackDuration,
            persistentID: mediaItem.persistentID
        )
    }

    /// Gets the playback URL for a library audio source.
    /// - Parameter source: The library audio source
    /// - Returns: The URL for playback, or nil if not accessible
    public func getPlaybackURL(for source: LibraryAudioSource) -> URL? {
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: source.persistentID,
            forProperty: MPMediaItemPropertyPersistentID
        ))

        guard let item = query.items?.first else {
            logger.warning("Could not find media item with persistentID: \(source.persistentID)")
            return nil
        }

        return item.assetURL
    }
}
