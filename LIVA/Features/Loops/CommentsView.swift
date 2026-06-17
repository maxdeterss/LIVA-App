import SwiftUI

struct CommentsView: View {
    let post: FeedPost
    var onCountChange: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [Comment] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var loading = true
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if loading {
                                ProgressView().tint(Theme.Palette.accent).frame(maxWidth: .infinity).padding(.top, 40)
                            } else if comments.isEmpty {
                                Text("No comments yet. Be the first to encourage them.")
                                    .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                                    .padding(.top, 24)
                            } else {
                                ForEach(comments) { c in commentRow(c) }
                            }
                        }
                        .padding(Theme.Spacing.screen)
                    }
                    composer
                }
            }
            .navigationTitle("Comments").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Palette.ink)
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private func commentRow(_ c: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(url: c.author?.avatarURL, initials: c.author?.initials ?? "?", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(c.author?.name ?? "member").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    if c.author?.isCreator == true { VerifiedBadge(size: 12) }
                    Text(c.createdAt, format: .relative(presentation: .named))
                        .font(.system(size: 11)).foregroundStyle(Theme.Palette.inkTertiary)
                }
                Text(c.body).font(.system(size: 14)).foregroundStyle(Theme.Palette.ink)
            }
            Spacer()
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $draft, axis: .vertical)
                .focused($focused).lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Capsule().fill(Theme.Palette.surfaceRaised))
                .overlay(Capsule().stroke(Theme.Palette.divider, lineWidth: 1))
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.Palette.tabBarText)
                    .frame(width: 38, height: 38).background(Circle().fill(Theme.Palette.ink))
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || sending)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Palette.background)
    }

    private func load() async {
        comments = (try? await FeedService.comments(for: post.id)) ?? []
        loading = false
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        sending = true
        defer { sending = false }
        if let comment = try? await FeedService.addComment(to: post.id, body: body) {
            comments.append(comment)
            draft = ""
            onCountChange(1)
        }
    }
}
