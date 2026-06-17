import SwiftUI

@main
struct LIVAApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Theme.Palette.ink)
                .preferredColorScheme(.light) // LIVA uses a fixed warm-cream light theme
                .task { session.start() }
        }
    }
}
