import SwiftUI

/// Log weight + body-fat. Trend is viewable in the body-metrics history.
struct LogWeightView: View {
    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var unit: Unit = .lbs
    @State private var saving = false

    enum Unit: String, CaseIterable { case lbs, kg }

    var body: some View {
        LogSheet(title: "Log Weight", canSave: parseDouble(weight) != nil, isSaving: saving) {
            save()
        } content: {
            Picker("Unit", selection: $unit) {
                ForEach(Unit.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }.pickerStyle(.segmented)
            NumberField(label: "Weight", text: $weight, unit: unit.rawValue, decimal: true)
            NumberField(label: "Body Fat (optional)", text: $bodyFat, unit: "%", decimal: true)
        }
    }

    private func save() {
        guard let v = parseDouble(weight) else { return }
        saving = true
        let kg = unit == .kg ? v : HealthMath.lbToKg(v)
        let body = BodyMetric(recordedAt: Date(), weightKg: kg, bodyFatPct: parseDouble(bodyFat),
                              source: .manual)
        Task { try? await env.body.log(body); saving = false; dismiss() }
    }
}
