import SwiftUI

/// A single feed post: author header, media, engagement actions and caption.
struct PostCardView: View {
    let post: FeedPost
    var onLike: () -> Void
    var onComment: () -> Void
    var onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorRow
            media
            actions
            if post.likeCount > 0 {
                Text("\(post.likeCount.formatted()) \(post.likeCount == 1 ? "like" : "likes")")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
            }
            if let caption = post.caption, !caption.isEmpty {
                captionView(caption)
            }
            if !post.hashtags.isEmpty {
                Text(post.hashtags.map { "#\($0)" }.joined(separator: " "))
                    .font(.system(size: 14)).foregroundStyle(Theme.Palette.accentDeep)
            }
            if post.commentCount > 0 {
                Button(action: onComment) {
                    Text("View all \(post.commentCount) comments")
                        .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            Text(post.createdAt, format: .relative(presentation: .named))
                .font(.system(size: 11)).foregroundStyle(Theme.Palette.inkTertiary)
        }
        .padding(Theme.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .stroke(Color.white.opacity(0.6), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }

    private var authorRow: some View {
        NavigationLink {
            ProfileView(userID: post.authorID)
        } label: {
            HStack(spacing: 10) {
                Avatar(url: post.authorAvatarURL, initials: String(post.authorName.prefix(1)).uppercased(), size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(post.authorName).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                        if post.authorIsCreator { VerifiedBadge(size: 13) }
                    }
                    if post.hasMusic {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note").font(.system(size: 10))
                            Text(post.musicLine).font(.system(size: 12))
                        }
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    } else {
                        Text(post.authorHandle).font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var media: some View {
        AsyncImage(url: URL(string: post.thumbnailURL ?? post.mediaURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                Rectangle().fill(Theme.Palette.chip).overlay(ProgressView().tint(Theme.Palette.accent))
            case .failure:
                Rectangle().fill(Theme.Palette.chip)
                    .overlay(Image(systemName: "photo").foregroundStyle(Theme.Palette.inkTertiary))
            @unknown default:
                Rectangle().fill(Theme.Palette.chip)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if post.mediaType == .video {
                Image(systemName: "play.circle.fill").font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.9)).padding(12)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 20) {
            Button(action: onLike) {
                Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                    .foregroundStyle(post.likedByMe ? Theme.Palette.like : Theme.Palette.ink)
            }
            Button(action: onComment) {
                Image(systemName: "bubble.right").foregroundStyle(Theme.Palette.ink)
            }
            Button(action: onSend) {
                Image(systemName: "paperplane").foregroundStyle(Theme.Palette.ink)
            }
            Spacer()
            Image(systemName: "bookmark").foregroundStyle(Theme.Palette.ink)
        }
        .font(.system(size: 22, weight: .regular))
    }

    private func captionView(_ caption: String) -> some View {
        Text("\(post.authorName) ").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
        + Text(caption).font(.system(size: 14)).foregroundStyle(Theme.Palette.ink)
    }
}
