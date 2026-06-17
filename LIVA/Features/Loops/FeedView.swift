import SwiftUI

struct FeedView: View {
    @StateObject private var model = FeedViewModel()
    @State private var showCreate = false
    @State private var commentsFor: FeedPost?
    @State private var sendFor: FeedPost?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                header
                if model.isLoading && !model.loadedOnce {
                    ProgressView().tint(Theme.Palette.accent).padding(.top, 60)
                } else if model.posts.isEmpty {
                    emptyState
                } else {
                    ForEach(model.posts) { post in
                        PostCardView(
                            post: post,
                            onLike: { model.toggleLike(post) },
                            onComment: { commentsFor = post },
                            onSend: { sendFor = post }
                        )
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationBarHidden(true)
        .refreshable { await model.load() }
        .task { if !model.loadedOnce { await model.load() } }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await model.load() } }) {
            CreatePostView()
        }
        .sheet(item: $commentsFor) { post in
            CommentsView(post: post) { delta in model.bumpCommentCount(for: post.id, by: delta) }
        }
        .sheet(item: $sendFor) { post in
            SendSheet(post: post)
        }
    }

    private var header: some View {
        HStack {
            BrandHeader(secondary: "loops", size: 28)
            Spacer()
            Button { showCreate = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.tabBarText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.Palette.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            EmptyStateView(
                systemName: "square.on.square",
                title: "Your feed is quiet",
                message: "Follow creators and friends to fill your loop with progress, not noise."
            )
            if !model.suggestions.isEmpty {
                LivaCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel("Suggested for you")
                        ForEach(model.suggestions) { p in
                            HStack(spacing: 12) {
                                Avatar(url: p.avatarURL, initials: p.initials, size: 44)
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(p.name).font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.Palette.ink)
                                        if p.isCreator == true { VerifiedBadge(size: 13) }
                                    }
                                    Text(p.handle).font(.system(size: 13))
                                        .foregroundStyle(Theme.Palette.inkSecondary)
                                }
                                Spacer()
                                Button("Follow") { model.follow(p.id) }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.tabBarText)
                                    .padding(.horizontal, 18).padding(.vertical, 8)
                                    .background(Capsule().fill(Theme.Palette.ink))
                            }
                            if p.id != model.suggestions.last?.id { Divider().overlay(Theme.Palette.divider) }
                        }
                    }
                }
            }
        }
    }
}
