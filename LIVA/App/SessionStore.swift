import Foundation
import SwiftUI
import Supabase

/// Single source of truth for auth + the signed-in user's profile.
///
/// Observes Supabase auth state and routes the app between the auth flow,
/// onboarding, and the main experience.
@MainActor
final class SessionStore: ObservableObject {

    enum Phase: Equatable {
        case loading      // resolving the persisted session
        case signedOut
        case onboarding   // authenticated but profile not completed
        case ready
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var profile: Profile?

    private var observer: Task<Void, Never>?
    private var started = false

    /// Called once from the app scene.
    func start() {
        guard !started else { return }
        started = true
        observer = Task { [weak self] in
            guard let self else { return }
            for await change in LIVA.supabase.auth.authStateChanges {
                await self.handle(event: change.event, session: change.session)
            }
        }
    }

    private func handle(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            if session != nil {
                await loadProfile()
            } else {
                phase = .signedOut
            }
        case .signedOut:
            profile = nil
            phase = .signedOut
        default:
            break
        }
    }

    /// Loads the current user's profile and derives the routing phase.
    func loadProfile() async {
        do {
            let profile = try await ProfileService.current()
            self.profile = profile
            phase = profile.onboardingComplete ? .ready : .onboarding
        } catch {
            // The profile row is created by a DB trigger; on a brand-new signup
            // it may lag by a moment. Either way, send the user to onboarding.
            phase = .onboarding
        }
    }

    func refresh() async { await loadProfile() }

    func completedOnboarding() async {
        await loadProfile()
    }

    func signOut() async {
        try? await AuthService.signOut()
        profile = nil
        phase = .signedOut
    }

    var userID: UUID? { LIVA.supabase.currentUserID }
}
