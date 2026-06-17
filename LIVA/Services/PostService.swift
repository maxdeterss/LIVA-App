import Foundation
import Supabase

/// Creates posts (uploading media first).
enum PostService {

    /// Uploads `mediaData` then inserts the post row, returning its id.
    @discardableResult
    static func create(
        mediaData: Data,
        mediaType: MediaType,
        caption: String?,
        hashtags: [String],
        taggedUserIDs: [UUID],
        musicTitle: String?,
        musicArtist: String?
    ) async throws -> UUID {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }

        let ext = mediaType == .image ? "jpg" : "mp4"
        let contentType = mediaType == .image ? "image/jpeg" : "video/mp4"
        let mediaURL = try await StorageService.upload(
            mediaData, bucket: .posts, fileExtension: ext, contentType: contentType
        )

        struct Row: Encodable {
            let author_id: String
            let media_url: String
            let media_type: String
            let caption: String?
            let hashtags: [String]
            let music_title: String?
            let music_artist: String?
        }
        struct Inserted: Decodable { let id: UUID }

        let data = try await LIVA.supabase.from("posts")
            .insert(Row(
                author_id: uid.uuidString,
                media_url: mediaURL,
                media_type: mediaType.rawValue,
                caption: caption,
                hashtags: hashtags,
                music_title: musicTitle,
                music_artist: musicArtist
            ))
            .select("id")
            .single()
            .execute().data
        let inserted = try AppJSON.decoder.decode(Inserted.self, from: data)

        if !taggedUserIDs.isEmpty {
            struct TagRow: Encodable { let post_id: String; let profile_id: String }
            let tags = taggedUserIDs.map { TagRow(post_id: inserted.id.uuidString, profile_id: $0.uuidString) }
            try await LIVA.supabase.from("post_tags").insert(tags).execute()
        }

        return inserted.id
    }
}
