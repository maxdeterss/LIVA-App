import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var suggestions: [ProfileLite] = []
    @Published var isLoading = false
    @Published var loadedOnce = false

    func load() async {
        isLoading = true
        defer { isLoading = false; loadedOnce = true }
        posts = (try? await FeedService.feed()) ?? []
        if posts.isEmpty {
            suggestions = (try? await ProfileService.suggestions()) ?? []
        }
    }

    /// Optimistic like toggle.
    func toggleLike(_ post: FeedPost) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let nowLiked = !posts[idx].likedByMe
        posts[idx].likedByMe = nowLiked
        posts[idx].likeCount += nowLiked ? 1 : -1
        Task {
            do {
                if nowLiked { try await FeedService.like(post: post.id) }
                else { try await FeedService.unlike(post: post.id) }
            } catch {
                // revert on failure
                posts[idx].likedByMe = !nowLiked
                posts[idx].likeCount += nowLiked ? -1 : 1
            }
        }
    }

    func bumpCommentCount(for postID: UUID, by delta: Int) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[idx].commentCount = max(0, posts[idx].commentCount + delta)
    }

    func follow(_ id: UUID) {
        suggestions.removeAll { $0.id == id }
        Task { try? await ProfileService.follow(id); await load() }
    }
}
