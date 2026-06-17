import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var stats: ProfileStats = .zero
    @Published var posts: [Post] = []
    @Published var links: [CreatorLink] = []
    @Published var isFollowing = false
    @Published var isLoading = false

    /// nil means "the signed-in user".
    let userID: UUID?
    private var resolvedID: UUID?

    init(userID: UUID?) { self.userID = userID }

    var isSelf: Bool {
        guard let resolvedID else { return userID == nil }
        return resolvedID == LIVA.supabase.currentUserID
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let id = userID ?? LIVA.supabase.currentUserID
        guard let id else { return }
        resolvedID = id

        async let profile = try? ProfileService.fetch(id: id)
        async let stats = try? ProfileService.stats(for: id)
        async let posts = try? FeedService.posts(by: id)
        async let links = try? ProfileService.links(for: id)
        async let following = (userID != nil) ? (try? ProfileService.isFollowing(id)) : false

        self.profile = await profile
        if let s = await stats { self.stats = s }
        self.posts = await posts ?? []
        self.links = await links ?? []
        self.isFollowing = await following ?? false
    }

    func toggleFollow() {
        guard let id = resolvedID else { return }
        let nowFollowing = !isFollowing
        isFollowing = nowFollowing
        stats.followersCount += nowFollowing ? 1 : -1
        Task {
            do {
                if nowFollowing { try await ProfileService.follow(id) }
                else { try await ProfileService.unfollow(id) }
            } catch {
                isFollowing = !nowFollowing
                stats.followersCount += nowFollowing ? -1 : 1
            }
        }
    }
}
