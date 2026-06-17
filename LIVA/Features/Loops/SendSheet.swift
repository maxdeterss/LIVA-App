import SwiftUI

/// Shares a post to another member via direct message (the "Send" action).
struct SendSheet: View {
    let post: FeedPost
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [ProfileLite] = []
    @State private var note = ""
    @State private var sentTo: Set<UUID> = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                VStack(spacing: 14) {
                    searchBar
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADD A NOTE (OPTIONAL)").font(.system(size: 11, weight: .semibold)).tracking(1)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                        TextField("Check this out…", text: $note).inputFieldStyle()
                    }
                    .padding(.horizontal, Theme.Spacing.screen)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if loading {
                                ProgressView().tint(Theme.Palette.accent).padding(.top, 30)
                            } else {
                                ForEach(results) { p in row(p) }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screen)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Send to").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Palette.ink)
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
        .task { await loadSuggestions() }
        .onChange(of: query) { _, _ in Task { await search() } }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Palette.inkSecondary)
            TextField("Search people", text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .inputFieldStyle()
        .padding(.horizontal, Theme.Spacing.screen)
    }

    private func row(_ p: ProfileLite) -> some View {
        let sent = sentTo.contains(p.id)
        return HStack(spacing: 12) {
            Avatar(url: p.avatarURL, initials: p.initials, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
                Text(p.handle).font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer()
            Button { Task { await sendTo(p) } } label: {
                Text(sent ? "Sent" : "Send")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(sent ? Theme.Palette.inkSecondary : Theme.Palette.tabBarText)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(sent ? Theme.Palette.chip : Theme.Palette.ink))
            }
            .disabled(sent)
        }
        .padding(.vertical, 8)
    }

    private func loadSuggestions() async {
        results = (try? await ProfileService.suggestions(limit: 20)) ?? []
        loading = false
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { await loadSuggestions(); return }
        results = (try? await ProfileService.search(q)) ?? []
    }

    private func sendTo(_ p: ProfileLite) async {
        try? await MessagingService.sharePost(post.id, to: p.id, note: note.isEmpty ? nil : note)
        sentTo.insert(p.id)
    }
}
