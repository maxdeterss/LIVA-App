import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model: ProfileViewModel
    @State private var tab: ProfileTab = .feed
    @State private var showSettings = false
    @State private var showEdit = false

    enum ProfileTab: String, CaseIterable { case loops = "LOOPS", feed = "FEED", groups = "GROUPS", tagged = "TAGGED" }

    init(userID: UUID? = nil) {
        _model = StateObject(wrappedValue: ProfileViewModel(userID: userID))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                identity
                statsBar
                actionButtons
                if model.isSelf, model.profile?.isCreator == true || !model.links.isEmpty {
                    creatorLinks
                }
                tabStrip
                grid
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationBarHidden(true)
        .refreshable { await model.load() }
        .task { await model.load() }
        .sheet(isPresented: $showSettings, onDismiss: { Task { await model.load() } }) {
            SettingsView()
        }
        .sheet(isPresented: $showEdit, onDismiss: { Task { await model.load(); await session.refresh() } }) {
            if let profile = model.profile { EditProfileView(profile: profile) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            BrandHeader(secondary: "profile", size: 28)
            Spacer()
            if model.isSelf {
                circleButton("gearshape") { showSettings = true }
                circleButton("square.and.arrow.up") {}
            }
        }
        .padding(.top, 4)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 40, height: 40).background(Circle().fill(Theme.Palette.chip))
        }.buttonStyle(.plain)
    }

    // MARK: Identity

    private var identity: some View {
        HStack(alignment: .top, spacing: 18) {
            Avatar(url: model.profile?.avatarURL, initials: model.profile?.initials ?? "L", size: 96)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(model.profile?.name.uppercased() ?? "—")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.Palette.ink)
                    if model.profile?.isCreator == true { VerifiedBadge(size: 18) }
                }
                Text(model.profile?.handle.uppercased() ?? "@—")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Palette.inkSecondary)
                if let bio = model.profile?.bio, !bio.isEmpty {
                    Text(bio).font(.system(size: 14)).foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let website = model.profile?.website, !website.isEmpty,
                   let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "link").font(.system(size: 11))
                            Text(website.replacingOccurrences(of: "https://", with: ""))
                                .font(.system(size: 13))
                        }.foregroundStyle(Theme.Palette.accentDeep)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: Stats

    private var statsBar: some View {
        LivaCard(padding: 18) {
            HStack {
                stat(model.stats.postsCount, "LOOPS")
                Divider().frame(height: 36).overlay(Theme.Palette.divider)
                stat(model.stats.followingCount, "FOLLOWING")
                Divider().frame(height: 36).overlay(Theme.Palette.divider)
                stat(model.stats.followersCount, "FOLLOWERS")
            }
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value.formatted()).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.system(size: 11, weight: .medium)).tracking(0.5)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    @ViewBuilder private var actionButtons: some View {
        if model.isSelf {
            Button("Edit Profile") { showEdit = true }
                .buttonStyle(SecondaryButtonStyle())
        } else {
            HStack(spacing: 12) {
                Button(model.isFollowing ? "Following" : "Follow") { model.toggleFollow() }
                    .buttonStyle(PrimaryButtonStyle(
                        fill: model.isFollowing ? Theme.Palette.chip : Theme.Palette.ink,
                        textColor: model.isFollowing ? Theme.Palette.ink : Theme.Palette.tabBarText))
                Button("Message") {}
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: Creator links

    private var creatorLinks: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Links")
                if model.links.isEmpty {
                    Text("Add social & affiliate links from Edit Profile.")
                        .font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
                } else {
                    ForEach(model.links) { link in
                        if let url = URL(string: link.url.hasPrefix("http") ? link.url : "https://\(link.url)") {
                            Link(destination: url) {
                                HStack(spacing: 12) {
                                    Image(systemName: link.kind.symbol).foregroundStyle(Theme.Palette.accent)
                                        .frame(width: 22)
                                    Text(link.label).font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.Palette.ink)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.system(size: 12))
                                        .foregroundStyle(Theme.Palette.inkSecondary)
                                }
                            }
                            if link.id != model.links.last?.id { Divider().overlay(Theme.Palette.divider) }
                        }
                    }
                }
            }
        }
    }

    // MARK: Tabs + grid

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { t in
                let active = tab == t
                Button { withAnimation { tab = t } } label: {
                    VStack(spacing: 8) {
                        Image(systemName: icon(for: t))
                            .font(.system(size: 16, weight: active ? .semibold : .regular))
                        Capsule().fill(active ? Theme.Palette.ink : .clear).frame(height: 2)
                    }
                    .foregroundStyle(active ? Theme.Palette.ink : Theme.Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func icon(for tab: ProfileTab) -> String {
        switch tab {
        case .loops: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .feed: return "square.grid.3x3"
        case .groups: return "person.3"
        case .tagged: return "person.crop.square"
        }
    }

    private var grid: some View {
        let cols = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]
        return Group {
            if tab == .feed || tab == .loops {
                if model.posts.isEmpty {
                    EmptyStateView(systemName: "camera",
                                   title: model.isSelf ? "Share your first Loop" : "No posts yet",
                                   message: model.isSelf ? "Your progress, workouts and wins live here." : "Check back soon.")
                } else {
                    LazyVGrid(columns: cols, spacing: 3) {
                        ForEach(model.posts) { post in
                            AsyncImage(url: URL(string: post.displayImageURL)) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(Theme.Palette.chip)
                                }
                            }
                            .frame(height: 130).frame(maxWidth: .infinity).clipped()
                            .overlay(alignment: .topTrailing) {
                                if post.mediaType == .video {
                                    Image(systemName: "play.fill").font(.system(size: 11))
                                        .foregroundStyle(.white).padding(6)
                                }
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(systemName: tab == .groups ? "person.3" : "person.crop.square",
                               title: tab == .groups ? "No groups yet" : "Nothing tagged",
                               message: "Coming soon to LIVA.")
            }
        }
    }
}
