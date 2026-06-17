import SwiftUI

/// LIVA's warm, minimal "cream" design language, derived from the product mockups:
/// off-white paper background, near-black ink, a single muted bronze/taupe accent,
/// and a dark pill tab bar.
enum Theme {

    // MARK: Palette
    enum Palette {
        static let background    = Color(hex: 0xECE8E0)   // warm paper
        static let surface       = Color(hex: 0xF6F3EC)   // card fill
        static let surfaceRaised = Color(hex: 0xFAF8F3)   // elevated card
        static let chip          = Color(hex: 0xE5E0D5)   // icon circle / chip bg
        static let ink           = Color(hex: 0x1B1A18)   // primary text
        static let inkSecondary  = Color(hex: 0x8C867A)   // labels / captions
        static let inkTertiary   = Color(hex: 0xB6B0A2)   // hints
        static let accent        = Color(hex: 0x9A8C73)   // bronze / taupe
        static let accentDeep    = Color(hex: 0x6F6552)   // emphasis
        static let track         = Color(hex: 0xDCD7CC)   // progress track
        static let divider       = Color(hex: 0xE0DCD2)
        static let tabBar        = Color(hex: 0x1E1C1A)
        static let tabBarText    = Color(hex: 0xF2EFE8)
        static let tabBarMuted   = Color(hex: 0x837E74)
        static let like          = Color(hex: 0xCB5B4C)
        static let verified      = Color(hex: 0x1B1A18)
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let screen: CGFloat = 20
    }

    // MARK: Radii
    enum Radius {
        static let chip: CGFloat = 14
        static let control: CGFloat = 16
        static let card: CGFloat = 24
        static let sheet: CGFloat = 28
        static let pill: CGFloat = 999
    }
}

// MARK: - Color from hex

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
