import SwiftUI

@main
struct LIVAApp: App {
    @StateObject private var session = SessionStore()
    @State private var health = HealthEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(health)
                .tint(Theme.Palette.ink)
                .preferredColorScheme(.light) // LIVA uses a fixed warm-cream light theme
                .task {
                    session.start()
                    await health.flushOfflineQueue() // replay anything logged offline
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await health.flushOfflineQueue() } }
                }
        }
    }
}
