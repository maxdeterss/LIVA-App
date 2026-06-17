import SwiftUI
import PhotosUI

struct EditProfileView: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var website = ""
    @State private var isCreator = false
    @State private var goal: Goal?
    @State private var interests: Set<ContentInterest> = []

    @State private var photoItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var avatarData: Data?

    @State private var links: [CreatorLink] = []
    @State private var showAddLink = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        avatarPicker
                        labeled("DISPLAY NAME") { TextField("Name", text: $displayName).inputFieldStyle() }
                        labeled("BIO") {
                            TextField("Tell people what you're about", text: $bio, axis: .vertical)
                                .lineLimit(2...5).inputFieldStyle()
                        }
                        labeled("WEBSITE") {
                            TextField("linktr.ee/you", text: $website)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .inputFieldStyle()
                        }

                        Toggle(isOn: $isCreator) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Creator mode").font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.ink)
                                Text("Unlock affiliate links & a verified badge.")
                                    .font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary)
                            }
                        }
                        .tint(Theme.Palette.accent)

                        goalSection
                        interestsSection
                        if isCreator { linksSection }
                    }
                    .padding(Theme.Spacing.screen)
                    .padding(.bottom, 90)
                }
                VStack {
                    Spacer()
                    Button { save() } label: {
                        HStack { if saving { ProgressView().tint(Theme.Palette.tabBarText) }; Text("Save Changes") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(Theme.Spacing.screen)
                    .background(Theme.Palette.background.opacity(0.95))
                }
            }
            .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
            .sheet(isPresented: $showAddLink) {
                AddLinkView { kind, label, url in
                    Task {
                        try? await ProfileService.addLink(kind: kind, label: label, url: url, position: links.count)
                        links = (try? await ProfileService.links(for: profile.id)) ?? links
                    }
                }
            }
            .onAppear(perform: populate)
            .task { links = (try? await ProfileService.links(for: profile.id)) ?? [] }
            .onChange(of: photoItem) { _, _ in Task { await loadPhoto() } }
        }
    }

    private var avatarPicker: some View {
        HStack { Spacer()
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let img = avatarImage {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle())
                    } else {
                        Avatar(url: profile.avatarURL, initials: profile.initials, size: 96)
                    }
                    Circle().fill(Theme.Palette.ink).frame(width: 30, height: 30)
                        .overlay(Image(systemName: "camera.fill").font(.system(size: 12)).foregroundStyle(.white))
                }
            }
            Spacer() }
    }

    private var goalSection: some View {
        labeled("GOAL") {
            FlowLayout(spacing: 8) {
                ForEach(Goal.allCases) { g in
                    SelectablePill(title: g.title, systemName: g.symbol, isSelected: goal == g) { goal = g }
                }
            }
        }
    }

    private var interestsSection: some View {
        labeled("INTERESTS") {
            FlowLayout(spacing: 8) {
                ForEach(ContentInterest.allCases) { i in
                    SelectablePill(title: i.title, systemName: i.symbol, isSelected: interests.contains(i)) {
                        if interests.contains(i) { interests.remove(i) } else { interests.insert(i) }
                    }
                }
            }
        }
    }

    private var linksSection: some View {
        labeled("LINKS") {
            VStack(spacing: 8) {
                ForEach(links) { link in
                    HStack(spacing: 12) {
                        Image(systemName: link.kind.symbol).foregroundStyle(Theme.Palette.accent).frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(link.label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.Palette.ink)
                            Text(link.url).font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary).lineLimit(1)
                        }
                        Spacer()
                        Button { delete(link) } label: { Image(systemName: "trash").foregroundStyle(Theme.Palette.like) }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.surfaceRaised))
                }
                Button { showAddLink = true } label: {
                    Label("Add link", systemImage: "plus").font(.system(size: 14, weight: .medium))
                }.buttonStyle(SecondaryButtonStyle())
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

    private func populate() {
        displayName = profile.displayName ?? ""
        bio = profile.bio ?? ""
        website = profile.website ?? ""
        isCreator = profile.isCreator
        goal = profile.goal
        interests = Set(profile.interestTags)
    }

    private func loadPhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        avatarImage = img
        avatarData = img.jpegData(compressionQuality: 0.85)
    }

    private func delete(_ link: CreatorLink) {
        links.removeAll { $0.id == link.id }
        Task { try? await ProfileService.deleteLink(link.id) }
    }

    private func save() {
        saving = true
        Task {
            var avatarURL: String?
            if let avatarData {
                avatarURL = try? await StorageService.upload(avatarData, bucket: .avatars,
                                                             fileExtension: "jpg", contentType: "image/jpeg")
            }
            try? await ProfileService.update(
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio,
                website: website.isEmpty ? nil : website,
                avatarURL: avatarURL,
                isCreator: isCreator,
                goal: goal,
                interests: Array(interests)
            )
            saving = false
            dismiss()
        }
    }
}

/// Small form for adding a creator link.
struct AddLinkView: View {
    var onAdd: (LinkKind, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: LinkKind = .social
    @State private var label = ""
    @State private var url = ""

    var body: some View {
        LogSheet(title: "Add Link",
                 canSave: !label.trimmingCharacters(in: .whitespaces).isEmpty && !url.trimmingCharacters(in: .whitespaces).isEmpty) {
            onAdd(kind, label, url); dismiss()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                Picker("Type", selection: $kind) {
                    ForEach(LinkKind.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("LABEL").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("My Protein Code", text: $label).inputFieldStyle()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("URL").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("https://…", text: $url)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().inputFieldStyle()
            }
        }
    }
}
