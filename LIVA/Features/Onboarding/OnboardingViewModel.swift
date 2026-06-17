import SwiftUI
import PhotosUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    @Published var username = ""
    @Published var displayName = ""
    @Published var bio = ""
    @Published var goal: Goal?
    @Published var interests: Set<ContentInterest> = []

    @Published var photoItem: PhotosPickerItem? { didSet { Task { await loadPhoto() } } }
    @Published var avatarImage: UIImage?
    private var avatarData: Data?

    @Published var isWorking = false
    @Published var error: String?

    let totalSteps = 3

    func prefill(from profile: Profile?) {
        if username.isEmpty { username = profile?.username ?? "" }
        if displayName.isEmpty { displayName = profile?.displayName ?? "" }
    }

    var canAdvance: Bool {
        switch step {
        case 0: return username.trimmingCharacters(in: .whitespaces).count >= 3
        case 1: return goal != nil
        case 2: return !interests.isEmpty
        default: return false
        }
    }

    func toggle(_ interest: ContentInterest) {
        if interests.contains(interest) { interests.remove(interest) }
        else { interests.insert(interest) }
    }

    func advance() { if step < totalSteps - 1 { withAnimation { step += 1 } } }
    func back() { if step > 0 { withAnimation { step -= 1 } } }

    private func loadPhoto() async {
        guard let photoItem else { return }
        if let data = try? await photoItem.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            avatarImage = image
            avatarData = image.jpegData(compressionQuality: 0.8)
        }
    }

    /// Validates the username, uploads the avatar, and writes the profile.
    func finish(session: SessionStore) async {
        error = nil
        guard let goal else { return }
        isWorking = true
        defer { isWorking = false }

        let name = username.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            guard try await ProfileService.usernameAvailable(name) else {
                error = "That username is taken — try another."
                withAnimation { step = 0 }
                return
            }

            var avatarURL: String?
            if let avatarData {
                avatarURL = try await StorageService.upload(
                    avatarData, bucket: .avatars, fileExtension: "jpg", contentType: "image/jpeg"
                )
            }

            try await ProfileService.completeOnboarding(
                username: name,
                displayName: displayName.isEmpty ? name : displayName,
                goal: goal,
                interests: Array(interests),
                avatarURL: avatarURL,
                bio: bio.isEmpty ? nil : bio
            )
            await session.completedOnboarding()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
