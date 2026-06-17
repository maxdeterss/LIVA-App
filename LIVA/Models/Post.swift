import Foundation

/// A feed item as returned by the `feed` RPC — a post joined with its author
/// and engagement counts.
struct FeedPost: Codable, Identifiable, Hashable {
    let id: UUID
    let authorID: UUID
    var mediaURL: String
    var mediaType: MediaType
    var thumbnailURL: String?
    var caption: String?
    var hashtags: [String]
    var musicTitle: String?
    var musicArtist: String?
    var createdAt: Date

    var authorUsername: String?
    var authorDisplayName: String?
    var authorAvatarURL: String?
    var authorIsCreator: Bool

    var likeCount: Int
    var commentCount: Int
    var likedByMe: Bool

    enum CodingKeys: String, CodingKey {
        case id, caption, hashtags
        case authorID = "author_id"
        case mediaURL = "media_url"
        case mediaType = "media_type"
        case thumbnailURL = "thumbnail_url"
        case musicTitle = "music_title"
        case musicArtist = "music_artist"
        case createdAt = "created_at"
        case authorUsername = "author_username"
        case authorDisplayName = "author_display_name"
        case authorAvatarURL = "author_avatar_url"
        case authorIsCreator = "author_is_creator"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case likedByMe = "liked_by_me"
    }

    var authorHandle: String { authorUsername.map { "@\($0)" } ?? "@member" }
    var authorName: String { authorDisplayName ?? authorUsername ?? "LIVA member" }
    var hasMusic: Bool { musicTitle?.isEmpty == false }
    var musicLine: String {
        [musicTitle, musicArtist].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A row of `public.posts` used when rendering a user's own grid.
struct Post: Codable, Identifiable, Hashable {
    let id: UUID
    let authorID: UUID
    var mediaURL: String
    var mediaType: MediaType
    var thumbnailURL: String?
    var caption: String?
    var hashtags: [String]
    var musicTitle: String?
    var musicArtist: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, caption, hashtags
        case authorID = "author_id"
        case mediaURL = "media_url"
        case mediaType = "media_type"
        case thumbnailURL = "thumbnail_url"
        case musicTitle = "music_title"
        case musicArtist = "music_artist"
        case createdAt = "created_at"
    }

    var displayImageURL: String { thumbnailURL ?? mediaURL }
}

/// A comment with its author joined in.
struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    var body: String
    var createdAt: Date
    var author: ProfileLite?

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case postID = "post_id"
        case authorID = "author_id"
        case createdAt = "created_at"
    }
}
