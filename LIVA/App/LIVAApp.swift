import SwiftUI

@main
struct LIVAApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Theme.Palette.ink)
                .task { session.start() }
        }
    }
}
