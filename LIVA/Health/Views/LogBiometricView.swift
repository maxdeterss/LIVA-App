import SwiftUI

/// Manual entry for any biometric.
struct LogBiometricView: View {
    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var metric: BiometricKind = .hrv
    @State private var value = ""
    @State private var saving = false

    var body: some View {
        LogSheet(title: "Log Biometric", canSave: parseDouble(value) != nil, isSaving: saving) {
            save()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("METRIC").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                Menu {
                    ForEach(BiometricKind.allCases) { m in
                        Button(m.title) { metric = m }
                    }
                } label: {
                    HStack {
                        Image(systemName: metric.symbol).foregroundStyle(Theme.Palette.accent)
                        Text(metric.title).foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    .inputFieldStyle()
                }
            }
            NumberField(label: "Value", text: $value, unit: metric.unit, decimal: true)
        }
    }

    private func save() {
        guard let v = parseDouble(value) else { return }
        saving = true
        let b = Biometric(recordedAt: Date(), metric: metric, value: v, unit: metric.unit, source: .manual)
        Task { try? await env.biometrics.log(b); saving = false; dismiss() }
    }
}
