import SwiftUI

/// Top-level router driven by `SessionStore.phase`.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        ZStack {
            LivaBackground()
            switch session.phase {
            case .loading:
                LaunchView()
            case .signedOut:
                AuthView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .ready:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
    }
}

/// Brand splash shown while the session resolves.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("LIVA")
                .font(.wordmark(64))
                .tracking(-2)
                .foregroundStyle(Theme.Palette.ink)
            ProgressView().tint(Theme.Palette.accent)
        }
    }
}
