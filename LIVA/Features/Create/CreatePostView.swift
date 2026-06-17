import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @StateObject private var model = CreatePostViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showTagPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        mediaPicker
                        if let error = model.error {
                            Text(error).font(.system(size: 13)).foregroundStyle(Theme.Palette.like)
                        }
                        labeled("CAPTION") {
                            TextField("Share the work behind the win…", text: $model.caption, axis: .vertical)
                                .lineLimit(3...8).inputFieldStyle()
                        }
                        labeled("HASHTAGS") {
                            TextField("legday mindset discipline", text: $model.hashtagText)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .inputFieldStyle()
                        }
                        tagPeople
                        labeled("MUSIC (OPTIONAL)") {
                            VStack(spacing: 8) {
                                TextField("Track title", text: $model.musicTitle).inputFieldStyle()
                                TextField("Artist", text: $model.musicArtist).inputFieldStyle()
                            }
                        }
                    }
                    .padding(Theme.Spacing.screen)
                    .padding(.bottom, 90)
                }
                VStack {
                    Spacer()
                    Button {
                        Task { if await model.post() { dismiss() } }
                    } label: {
                        HStack {
                            if model.isPosting { ProgressView().tint(Theme.Palette.tabBarText) }
                            Text("Share to LIVA")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!model.canPost)
                    .opacity(model.canPost ? 1 : 0.6)
                    .padding(Theme.Spacing.screen)
                    .background(Theme.Palette.background.opacity(0.95))
                }
            }
            .navigationTitle("New Loop").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink)
                }
            }
            .sheet(isPresented: $showTagPicker) {
                UserPickerView { model.addTag($0) }
            }
        }
    }

    private var mediaPicker: some View {
        PhotosPicker(selection: $model.pickerItem, matching: .any(of: [.images, .videos])) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .frame(height: 320)
                if let image = model.previewImage {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(height: 320).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                } else if model.mediaType == .video && model.pickerItem != nil {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill").font(.system(size: 34))
                        Text("Video selected").font(.system(size: 14, weight: .medium))
                    }.foregroundStyle(Theme.Palette.inkSecondary)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 34))
                        Text("Add a photo or video").font(.system(size: 15, weight: .medium))
                        Text("Up to 60 seconds").font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.inkTertiary)
                    }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var tagPeople: some View {
        labeled("TAG PEOPLE") {
            VStack(alignment: .leading, spacing: 10) {
                if !model.taggedUsers.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(model.taggedUsers) { p in
                            HStack(spacing: 6) {
                                Text(p.handle).font(.system(size: 13, weight: .medium))
                                Button { model.removeTag(p) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                            }
                            .foregroundStyle(Theme.Palette.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Theme.Palette.chip))
                        }
                    }
                }
                Button { showTagPicker = true } label: {
                    Label("Tag people", systemImage: "person.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            content()
        }
    }
}

/// Reusable searchable user picker (used for tagging).
struct UserPickerView: View {
    var onSelect: (ProfileLite) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ProfileLite] = []

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.Palette.inkSecondary)
                        TextField("Search people", text: $query)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .inputFieldStyle().padding(.horizontal, Theme.Spacing.screen)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { p in
                                Button { onSelect(p); dismiss() } label: {
                                    HStack(spacing: 12) {
                                        Avatar(url: p.avatarURL, initials: p.initials, size: 40)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(p.name).font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Theme.Palette.ink)
                                            Text(p.handle).font(.system(size: 13))
                                                .foregroundStyle(Theme.Palette.inkSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screen)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Tag people").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
            .task { await loadSuggestions() }
            .onChange(of: query) { _, _ in Task { await search() } }
        }
        .presentationDetents([.large, .medium])
    }

    private func loadSuggestions() async {
        results = (try? await ProfileService.suggestions(limit: 20)) ?? []
    }
    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { await loadSuggestions(); return }
        results = (try? await ProfileService.search(q)) ?? []
    }
}
