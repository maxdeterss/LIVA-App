import SwiftUI

/// Type ramp for LIVA.
///
/// The brand wordmark uses a heavy condensed grotesque (Archivo Black in the
/// brand assets). We approximate with the system black weight so the app builds
/// with zero bundled fonts; drop `ArchivoBlack` into the project and swap
/// `wordmark` to use it for a pixel-perfect match.
extension Font {
    static func wordmark(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    /// The lighter serif companion word ("health", "profile") in the mockups.
    static func brandSerif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func sectionLabel() -> Font {
        .system(size: 12, weight: .semibold, design: .default)
    }

    static func statNumber(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

// MARK: - Reusable text styles

/// Small uppercase tracked label used on every card header (BIOMETRICS, NUTRITION…).
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.sectionLabel())
            .tracking(1.4)
            .foregroundStyle(Theme.Palette.ink)
    }
}

/// "VIEW ALL ›" trailing action seen on dashboard cards.
struct ViewAllLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("VIEW ALL")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Theme.Palette.inkSecondary)
    }
}
