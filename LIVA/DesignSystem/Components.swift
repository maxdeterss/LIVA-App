import SwiftUI

// MARK: - Screen background

/// Warm paper background used on every screen.
struct LivaBackground: View {
    var body: some View {
        Theme.Palette.background.ignoresSafeArea()
    }
}

// MARK: - Card

/// Soft, elevated rounded card matching the dashboard surfaces.
struct LivaCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.xl
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Buttons

/// Primary dark pill button ("Join waitlist", "Continue").
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.Palette.ink
    var textColor: Color = Theme.Palette.tabBarText
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(fill)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet secondary button with a hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.Palette.chip)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Icon circle

/// Round chip behind an SF Symbol, as seen on the biometrics row.
struct IconCircle: View {
    let systemName: String
    var size: CGFloat = 48
    var fill: Color = Theme.Palette.chip
    var tint: Color = Theme.Palette.ink
    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.38, weight: .regular))
                    .foregroundStyle(tint)
            )
    }
}

// MARK: - Avatar

/// Remote avatar with an initials fallback.
struct Avatar: View {
    let url: String?
    let initials: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.5))
    }

    private var placeholder: some View {
        ZStack {
            Theme.Palette.chip
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}

// MARK: - Progress ring (nutrition)

/// Open-gap progress ring used for the calorie total.
struct ProgressRing: View {
    var progress: Double           // 0...1+
    var lineWidth: CGFloat = 10
    var size: CGFloat = 150

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    Theme.Palette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Macro bar

/// Horizontal value/target bar for protein / carbs / fats.
struct MacroBar: View {
    let label: String
    let value: Int
    let target: Int
    var unit: String = "G"

    private var progress: Double { target > 0 ? min(Double(value) / Double(target), 1) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.Palette.ink)
                Spacer()
                Text("\(value) / \(target)\(unit)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.track)
                    Capsule().fill(Theme.Palette.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Chips

/// Selectable pill used for goals / interests.
struct SelectablePill: View {
    let title: String
    let systemName: String?
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemName {
                    Image(systemName: systemName).font(.system(size: 13, weight: .medium))
                }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? Theme.Palette.tabBarText : Theme.Palette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? Theme.Palette.ink : Theme.Palette.chip)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Brand header

/// "LIVA health" / "LIVA profile" lockup used at the top of primary screens.
struct BrandHeader: View {
    let secondary: String
    var size: CGFloat = 30
    var body: some View {
        HStack(spacing: 8) {
            Text("LIVA").font(.wordmark(size)).tracking(-1)
            Text(secondary).font(.brandSerif(size * 0.85))
                .foregroundStyle(Theme.Palette.ink)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.Palette.ink)
    }
}

// MARK: - Verified badge

struct VerifiedBadge: View {
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size))
            .foregroundStyle(Theme.Palette.verified)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let systemName: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            IconCircle(systemName: systemName, size: 64)
            Text(title).font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
            Text(message).font(.system(size: 14))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}
