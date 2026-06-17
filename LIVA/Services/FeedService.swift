import Foundation
import Supabase

/// The social graph: feed, posts, likes and comments.
enum FeedService {

    struct FeedParams: Encodable {
        let limit_count: Int
        let before: String
    }

    /// Posts from people the user follows (plus their own), newest first.
    static func feed(limit: Int = 30, before: Date = Date()) async throws -> [FeedPost] {
        let params = FeedParams(
            limit_count: limit,
            before: ISO8601DateFormatter().string(from: before)
        )
        let data = try await LIVA.supabase.rpc("feed", params: params).execute().data
        return try AppJSON.decoder.decode([FeedPost].self, from: data)
    }

    /// All posts authored by one user (for profile grids).
    static func posts(by author: UUID, limit: Int = 60) async throws -> [Post] {
        let data = try await LIVA.supabase
            .from("posts").select()
            .eq("author_id", value: author.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute().data
        return try AppJSON.decoder.decode([Post].self, from: data)
    }

    static func post(id: UUID) async throws -> Post {
        let data = try await LIVA.supabase
            .from("posts").select().eq("id", value: id.uuidString).single()
            .execute().data
        return try AppJSON.decoder.decode(Post.self, from: data)
    }

    static func delete(post id: UUID) async throws {
        try await LIVA.supabase.from("posts").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: Likes

    static func like(post id: UUID) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable { let post_id: String; let profile_id: String }
        try await LIVA.supabase.from("likes")
            .upsert(Row(post_id: id.uuidString, profile_id: uid.uuidString))
            .execute()
    }

    static func unlike(post id: UUID) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        try await LIVA.supabase.from("likes").delete()
            .eq("post_id", value: id.uuidString)
            .eq("profile_id", value: uid.uuidString)
            .execute()
    }

    // MARK: Comments

    static func comments(for post: UUID) async throws -> [Comment] {
        let data = try await LIVA.supabase
            .from("comments")
            .select("id, post_id, author_id, body, created_at, author:profiles(id, username, display_name, avatar_url, is_creator)")
            .eq("post_id", value: post.uuidString)
            .order("created_at", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([Comment].self, from: data)
    }

    @discardableResult
    static func addComment(to post: UUID, body: String) async throws -> Comment {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable { let post_id: String; let author_id: String; let body: String }
        let data = try await LIVA.supabase.from("comments")
            .insert(Row(post_id: post.uuidString, author_id: uid.uuidString, body: body))
            .select("id, post_id, author_id, body, created_at, author:profiles(id, username, display_name, avatar_url, is_creator)")
            .single()
            .execute().data
        return try AppJSON.decoder.decode(Comment.self, from: data)
    }

    static func deleteComment(_ id: UUID) async throws {
        try await LIVA.supabase.from("comments").delete().eq("id", value: id.uuidString).execute()
    }
}
