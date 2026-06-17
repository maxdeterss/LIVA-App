import SwiftUI

/// A single biometric tile: icon chip, big value, small label. Used in the
/// dashboard BIOMETRICS row and detail grids.
struct MetricChip: View {
    let symbol: String
    let value: String
    let label: String
    var iconSize: CGFloat = 46

    var body: some View {
        VStack(spacing: 8) {
            IconCircle(systemName: symbol, size: iconSize)
            Text(value).font(.statNumber(20)).foregroundStyle(Theme.Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 10, weight: .medium)).tracking(0.5)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.replacingOccurrences(of: "\n", with: " ")): \(value)")
    }
}

/// A labeled value/target progress bar (Protein / Carbs / Fats). Distinct from
/// the MVP `MacroBar` so the Health module owns a consistent, reusable control.
struct SegmentedProgressBar: View {
    let label: String
    let value: Int
    let target: Int
    var unit: String = "G"
    var tint: Color = Theme.Palette.accent

    private var progress: Double { HealthMath.progress(value, target: target) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Theme.Palette.ink)
                Spacer()
                Text("\(value) / \(target)\(unit)").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.track)
                    Capsule().fill(tint).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) of \(target) \(unit)")
    }
}
