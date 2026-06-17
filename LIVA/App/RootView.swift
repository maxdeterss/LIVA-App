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
        VStack(spacing: 22) {
            BrandMarkView(size: 88)
            ProgressView().tint(Theme.Palette.accent)
        }
    }
}

/// The LIVA "VA" monogram, drawn as a vector so it stays crisp at any size and
/// tints to any ink color. Geometry matches the brand icon (1024×1024 space).
struct BrandMarkView: View {
    var size: CGFloat = 64
    var color: Color = Theme.Palette.ink
    var body: some View {
        LIVAMarkShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: size, height: size)
    }
}

/// The "VA" ligature path. Uses even-odd fill so the counter of the A is cut out.
struct LIVAMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 1024
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()

        // V + left stroke
        path.move(to: p(524.34, 784.80))
        [(375.54, 784.80), (308.27, 238.89), (412.12, 238.89),
         (452.11, 610.27), (487.76, 238.89), (591.61, 238.89),
         (524.34, 784.80)].forEach { path.addLine(to: p($0.0, $0.1)) }
        path.closeSubpath()

        // A
        path.move(to: p(530.04, 784.80))
        [(424.02, 784.80), (476.72, 239.20), (661.79, 239.20),
         (713.56, 784.80), (610.33, 784.80), (602.58, 696.76),
         (536.86, 696.76), (530.04, 784.80)].forEach { path.addLine(to: p($0.0, $0.1)) }
        path.closeSubpath()

        // Counter of the A (subtracted via even-odd)
        path.move(to: p(565.38, 332.20))
        [(544.61, 609.65), (594.21, 609.65), (570.34, 332.20),
         (565.38, 332.20)].forEach { path.addLine(to: p($0.0, $0.1)) }
        path.closeSubpath()

        return path
    }
}
