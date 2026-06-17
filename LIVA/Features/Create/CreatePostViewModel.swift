import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
final class CreatePostViewModel: ObservableObject {
    @Published var pickerItem: PhotosPickerItem? { didSet { Task { await loadMedia() } } }
    @Published var previewImage: UIImage?
    @Published var mediaType: MediaType = .image

    @Published var caption = ""
    @Published var hashtagText = ""
    @Published var musicTitle = ""
    @Published var musicArtist = ""
    @Published var taggedUsers: [ProfileLite] = []

    @Published var isPosting = false
    @Published var error: String?

    private var mediaData: Data?

    var canPost: Bool { mediaData != nil && !isPosting }

    var hashtags: [String] {
        hashtagText
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "#" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func loadMedia() async {
        guard let pickerItem else { return }
        error = nil
        let isMovie = pickerItem.supportedContentTypes.contains { $0.conforms(to: .movie) }
        guard let data = try? await pickerItem.loadTransferable(type: Data.self) else {
            error = "Couldn't load that media."
            return
        }
        mediaData = data
        if isMovie {
            mediaType = .video
            previewImage = nil
        } else if let image = UIImage(data: data) {
            mediaType = .image
            // Re-encode to a sensible JPEG to keep uploads light.
            mediaData = image.jpegData(compressionQuality: 0.85) ?? data
            previewImage = image
        }
    }

    func addTag(_ profile: ProfileLite) {
        guard !taggedUsers.contains(where: { $0.id == profile.id }) else { return }
        taggedUsers.append(profile)
    }

    func removeTag(_ profile: ProfileLite) {
        taggedUsers.removeAll { $0.id == profile.id }
    }

    /// Returns true on success so the view can dismiss.
    func post() async -> Bool {
        guard let mediaData else { return false }
        isPosting = true
        defer { isPosting = false }
        do {
            try await PostService.create(
                mediaData: mediaData,
                mediaType: mediaType,
                caption: caption.isEmpty ? nil : caption,
                hashtags: hashtags,
                taggedUserIDs: taggedUsers.map(\.id),
                musicTitle: musicTitle.isEmpty ? nil : musicTitle,
                musicArtist: musicArtist.isEmpty ? nil : musicArtist
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
