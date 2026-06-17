import Foundation
import Supabase

/// Reads & writes profiles, the follow graph, and creator links.
enum ProfileService {

    // MARK: Profiles

    static func fetch(id: UUID) async throws -> Profile {
        let data = try await LIVA.supabase
            .from("profiles").select().eq("id", value: id.uuidString).single()
            .execute().data
        return try AppJSON.decoder.decode(Profile.self, from: data)
    }

    static func current() async throws -> Profile {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        return try await fetch(id: uid)
    }

    static func usernameAvailable(_ candidate: String) async throws -> Bool {
        let data = try await LIVA.supabase
            .rpc("username_available", params: ["candidate": candidate])
            .execute().data
        return try AppJSON.decoder.decode(Bool.self, from: data)
    }

    /// Persists the onboarding answers and flips `onboarding_complete`.
    static func completeOnboarding(
        username: String,
        displayName: String,
        goal: Goal,
        interests: [ContentInterest],
        avatarURL: String?,
        bio: String?
    ) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Payload: Encodable {
            let username: String
            let display_name: String
            let goal: String
            let interests: [String]
            let avatar_url: String?
            let bio: String?
            let onboarding_complete: Bool
        }
        let payload = Payload(
            username: username,
            display_name: displayName,
            goal: goal.rawValue,
            interests: interests.map(\.rawValue),
            avatar_url: avatarURL,
            bio: bio,
            onboarding_complete: true
        )
        try await LIVA.supabase.from("profiles")
            .update(payload).eq("id", value: uid.uuidString).execute()
    }

    /// Generic profile patch used by the edit screen.
    static func update(
        displayName: String?,
        bio: String?,
        website: String?,
        avatarURL: String?,
        isCreator: Bool?,
        goal: Goal?,
        interests: [ContentInterest]?
    ) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Payload: Encodable {
            var display_name: String?
            var bio: String?
            var website: String?
            var avatar_url: String?
            var is_creator: Bool?
            var goal: String?
            var interests: [String]?
        }
        let payload = Payload(
            display_name: displayName,
            bio: bio,
            website: website,
            avatar_url: avatarURL,
            is_creator: isCreator,
            goal: goal?.rawValue,
            interests: interests?.map(\.rawValue)
        )
        try await LIVA.supabase.from("profiles")
            .update(payload).eq("id", value: uid.uuidString).execute()
    }

    static func stats(for id: UUID) async throws -> ProfileStats {
        let data = try await LIVA.supabase
            .rpc("profile_stats", params: ["p": id.uuidString])
            .execute().data
        // The RPC returns a single-row table → an array of one object.
        let rows = try AppJSON.decoder.decode([ProfileStats].self, from: data)
        return rows.first ?? .zero
    }

    static func search(_ query: String, limit: Int = 20) async throws -> [ProfileLite] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let data = try await LIVA.supabase
            .from("profiles")
            .select("id, username, display_name, avatar_url, is_creator")
            .or("username.ilike.%\(trimmed)%,display_name.ilike.%\(trimmed)%")
            .limit(limit)
            .execute().data
        return try AppJSON.decoder.decode([ProfileLite].self, from: data)
    }

    // MARK: Following

    static func isFollowing(_ id: UUID) async throws -> Bool {
        guard let uid = LIVA.supabase.currentUserID else { return false }
        let data = try await LIVA.supabase
            .from("follows").select("follower_id")
            .eq("follower_id", value: uid.uuidString)
            .eq("following_id", value: id.uuidString)
            .execute().data
        let rows = try AppJSON.decoder.decode([[String: String]].self, from: data)
        return !rows.isEmpty
    }

    static func follow(_ id: UUID) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable { let follower_id: String; let following_id: String }
        try await LIVA.supabase.from("follows")
            .upsert(Row(follower_id: uid.uuidString, following_id: id.uuidString))
            .execute()
    }

    static func unfollow(_ id: UUID) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        try await LIVA.supabase.from("follows").delete()
            .eq("follower_id", value: uid.uuidString)
            .eq("following_id", value: id.uuidString)
            .execute()
    }

    /// Profiles to suggest when the feed is empty (most recent members).
    static func suggestions(limit: Int = 12) async throws -> [ProfileLite] {
        let data = try await LIVA.supabase
            .from("profiles")
            .select("id, username, display_name, avatar_url, is_creator")
            .eq("onboarding_complete", value: true)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute().data
        let all = try AppJSON.decoder.decode([ProfileLite].self, from: data)
        return all.filter { $0.id != LIVA.supabase.currentUserID }
    }

    // MARK: Creator links

    static func links(for id: UUID) async throws -> [CreatorLink] {
        let data = try await LIVA.supabase
            .from("creator_links").select()
            .eq("profile_id", value: id.uuidString)
            .order("position", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([CreatorLink].self, from: data)
    }

    static func addLink(kind: LinkKind, label: String, url: String, position: Int) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable {
            let profile_id: String; let kind: String
            let label: String; let url: String; let position: Int
        }
        try await LIVA.supabase.from("creator_links")
            .insert(Row(profile_id: uid.uuidString, kind: kind.rawValue,
                        label: label, url: url, position: position))
            .execute()
    }

    static func deleteLink(_ id: UUID) async throws {
        try await LIVA.supabase.from("creator_links").delete()
            .eq("id", value: id.uuidString).execute()
    }
}
