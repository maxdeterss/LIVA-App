import SwiftUI

// MARK: - Shared sheet scaffold

/// Standard logging sheet chrome: title, cancel, and a sticky Save button.
struct LogSheet<Content: View>: View {
    let title: String
    let canSave: Bool
    var isSaving: Bool = false
    let onSave: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) { content }
                        .padding(Theme.Spacing.screen)
                        .padding(.bottom, 90)
                }
                VStack {
                    Spacer()
                    Button { onSave() } label: {
                        HStack {
                            if isSaving { ProgressView().tint(Theme.Palette.tabBarText) }
                            Text("Save")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave || isSaving)
                    .opacity(canSave ? 1 : 0.6)
                    .padding(Theme.Spacing.screen)
                    .background(Theme.Palette.background.opacity(0.95))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

/// Labeled numeric input row.
struct NumberField: View {
    let label: String
    @Binding var text: String
    var unit: String = ""
    var decimal: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(Theme.Palette.inkSecondary)
            HStack {
                TextField("0", text: $text)
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .inputFieldStyle()
        }
    }
}

private func intValue(_ s: String) -> Int? { Int(s.trimmingCharacters(in: .whitespaces)) }
private func doubleValue(_ s: String) -> Double? { Double(s.trimmingCharacters(in: .whitespaces)) }

// MARK: - Weight

struct LogWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var unit = Unit.lbs
    @State private var note = ""
    @State private var saving = false
    enum Unit: String, CaseIterable { case lbs, kg }

    var body: some View {
        LogSheet(title: "Log Weight", canSave: doubleValue(weight) != nil, isSaving: saving) {
            save()
        } content: {
            Picker("Unit", selection: $unit) {
                ForEach(Unit.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }.pickerStyle(.segmented)
            NumberField(label: "Weight", text: $weight, unit: unit.rawValue, decimal: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE (OPTIONAL)").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("How are you feeling?", text: $note).inputFieldStyle()
            }
        }
    }

    private func save() {
        guard let value = doubleValue(weight) else { return }
        let kg = unit == .kg ? value : value / 2.2046226218
        saving = true
        Task {
            try? await TrackingService.logWeight(weightKg: kg, note: note.isEmpty ? nil : note)
            saving = false; dismiss()
        }
    }
}

// MARK: - Biometrics

struct LogBiometricsView: View {
    let existing: DailyMetric?
    @Environment(\.dismiss) private var dismiss
    @State private var steps = ""
    @State private var hrv = ""
    @State private var rhr = ""
    @State private var sleep = ""
    @State private var spo2 = ""
    @State private var temp = ""
    @State private var saving = false

    var body: some View {
        LogSheet(title: "Biometrics", canSave: true, isSaving: saving) {
            save()
        } content: {
            Text("Update today's readings. Anything you leave blank stays unchanged.")
                .font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
            NumberField(label: "Steps", text: $steps)
            NumberField(label: "HRV", text: $hrv, unit: "ms")
            NumberField(label: "Resting HR", text: $rhr, unit: "bpm")
            NumberField(label: "Sleep", text: $sleep, unit: "hrs", decimal: true)
            NumberField(label: "SpO₂", text: $spo2, unit: "%")
            NumberField(label: "Body Temp", text: $temp, unit: "°F", decimal: true)
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let m = existing else { return }
        steps = m.steps.map(String.init) ?? ""
        hrv = m.hrv.map(String.init) ?? ""
        rhr = m.restingHR.map(String.init) ?? ""
        sleep = m.sleepHours.map { String($0) } ?? ""
        spo2 = m.spo2.map(String.init) ?? ""
        temp = m.tempF.map { String($0) } ?? ""
    }

    private func save() {
        saving = true
        Task {
            try? await TrackingService.saveMetric(
                steps: intValue(steps), hrv: intValue(hrv), restingHR: intValue(rhr),
                sleepHours: doubleValue(sleep), spo2: intValue(spo2), tempF: doubleValue(temp)
            )
            saving = false; dismiss()
        }
    }
}

// MARK: - Meal

struct LogMealView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var meal: MealType = .lunch
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fats = ""
    @State private var saving = false

    var body: some View {
        LogSheet(title: "Log Meal",
                 canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty && intValue(calories) != nil,
                 isSaving: saving) {
            save()
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text("MEAL NAME").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("Grilled chicken & rice", text: $name).inputFieldStyle()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("WHEN").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }
            NumberField(label: "Calories", text: $calories, unit: "cal")
            HStack(spacing: 12) {
                NumberField(label: "Protein", text: $protein, unit: "g")
                NumberField(label: "Carbs", text: $carbs, unit: "g")
                NumberField(label: "Fats", text: $fats, unit: "g")
            }
        }
    }

    private func save() {
        guard let cal = intValue(calories) else { return }
        saving = true
        let log = NutritionLog(
            id: nil, profileID: nil, name: name, meal: meal, calories: cal,
            proteinG: intValue(protein) ?? 0, carbsG: intValue(carbs) ?? 0,
            fatsG: intValue(fats) ?? 0, loggedOn: Date()
        )
        Task {
            try? await TrackingService.logMeal(log)
            saving = false; dismiss()
        }
    }
}
