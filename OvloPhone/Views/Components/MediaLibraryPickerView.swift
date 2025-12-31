import SwiftUI
import MediaPlayer

/// SwiftUI wrapper for MPMediaPickerController to select audio from Apple Music library.
struct MediaLibraryPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (MPMediaItem) -> Void

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false  // Only show downloaded items
        picker.prompt = "Select a track for meditation"
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let parent: MediaLibraryPickerView

        init(_ parent: MediaLibraryPickerView) {
            self.parent = parent
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            if let item = mediaItemCollection.items.first {
                parent.onSelect(item)
            }
            parent.dismiss()
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    MediaLibraryPickerView { item in
        print("Selected: \(item.title ?? "Unknown")")
    }
}
