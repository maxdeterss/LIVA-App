import Foundation

/// A user profile (row of `public.profiles`).
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String?
    var displayName: String?
    var avatarURL: String?
    var bio: String?
    var goal: Goal?
    var interests: [String]
    var isCreator: Bool
    var website: String?
    var onboardingComplete: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, goal, interests, website
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case isCreator = "is_creator"
        case onboardingComplete = "onboarding_complete"
        case createdAt = "created_at"
    }

    var handle: String { username.map { "@\($0)" } ?? "@you" }
    var name: String { displayName ?? username ?? "LIVA member" }
    var initials: String {
        let source = displayName ?? username ?? "L"
        let parts = source.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].first!)\(parts[1].first!)".uppercased() }
        return String(source.prefix(1)).uppercased()
    }

    var interestTags: [ContentInterest] {
        interests.compactMap(ContentInterest.init(rawValue:))
    }
}

/// Lightweight profile used in lists, search and tagging.
struct ProfileLite: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String?
    var displayName: String?
    var avatarURL: String?
    var isCreator: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case isCreator = "is_creator"
    }

    var handle: String { username.map { "@\($0)" } ?? "@member" }
    var name: String { displayName ?? username ?? "LIVA member" }
    var initials: String {
        let source = displayName ?? username ?? "L"
        return String(source.prefix(1)).uppercased()
    }
}

/// Aggregate counts returned by the `profile_stats` RPC.
struct ProfileStats: Codable {
    var postsCount: Int
    var followersCount: Int
    var followingCount: Int

    enum CodingKeys: String, CodingKey {
        case postsCount = "posts_count"
        case followersCount = "followers_count"
        case followingCount = "following_count"
    }

    static let zero = ProfileStats(postsCount: 0, followersCount: 0, followingCount: 0)
}

/// A creator's social / affiliate link.
struct CreatorLink: Codable, Identifiable, Hashable {
    let id: UUID
    var profileID: UUID
    var kind: LinkKind
    var label: String
    var url: String
    var position: Int

    enum CodingKeys: String, CodingKey {
        case id, kind, label, url, position
        case profileID = "profile_id"
    }
}
