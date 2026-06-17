import SwiftUI

// MARK: - Biometrics + weight history

struct BiometricsDetailView: View {
    @State private var weights: [WeightLog] = []
    @State private var metric: DailyMetric?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Biometrics").font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.Palette.ink)

                LivaCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel("Today")
                        grid
                    }
                }

                LivaCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel("Weight history")
                        if weights.isEmpty {
                            Text("No weigh-ins yet.").font(.system(size: 14))
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        } else {
                            ForEach(weights) { w in
                                HStack {
                                    Text(w.loggedOn, format: .dateTime.month().day().year())
                                        .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                                    Spacer()
                                    Text(String(format: "%.1f lbs", w.weightLbs))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.ink)
                                }
                                if w.id != weights.last?.id { Divider().overlay(Theme.Palette.divider) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task {
            weights = (try? await TrackingService.recentWeights()) ?? []
            metric = try? await TrackingService.metric()
        }
    }

    private var grid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 16) {
            cell("HRV", metric?.hrv.map(String.init), "heart.text.square")
            cell("Resting HR", metric?.restingHR.map(String.init), "heart")
            cell("Sleep", metric?.sleepHours.map { String($0) }, "moon.zzz")
            cell("SpO₂", metric?.spo2.map { "\($0)%" }, "drop")
            cell("Temp", metric?.tempF.map { "\($0)°" }, "thermometer.medium")
            cell("Steps", metric?.steps.map { $0.formatted() }, "figure.walk")
        }
    }

    private func cell(_ label: String, _ value: String?, _ icon: String) -> some View {
        VStack(spacing: 6) {
            IconCircle(systemName: icon, size: 42)
            Text(value ?? "—").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workouts list

struct WorkoutsListView: View {
    @State private var workouts: [WorkoutLog] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Workouts").font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.Palette.ink)
                if loading {
                    ProgressView().tint(Theme.Palette.accent).frame(maxWidth: .infinity).padding(.top, 40)
                } else if workouts.isEmpty {
                    EmptyStateView(systemName: "dumbbell", title: "No workouts logged",
                                   message: "Tap + on the dashboard to log your first session.")
                } else {
                    ForEach(workouts) { workout in
                        WorkoutRow(workout: workout)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task {
            workouts = (try? await TrackingService.recentWorkouts()) ?? []
            loading = false
        }
    }
}

struct WorkoutRow: View {
    let workout: WorkoutLog
    var body: some View {
        LivaCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconCircle(systemName: workout.type.symbol, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.title).font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                        Text(workout.loggedAt, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        if let d = workout.durationMin { Text("\(d) min").font(.system(size: 14, weight: .medium)) }
                        if let c = workout.calories { Text("\(c) cal").font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary) }
                    }
                }
                if let exercises = workout.exercises, !exercises.isEmpty {
                    Divider().overlay(Theme.Palette.divider)
                    ForEach(exercises) { ex in
                        HStack {
                            Text(ex.name).font(.system(size: 14)).foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            Text(setRepText(ex)).font(.system(size: 13))
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                }
            }
        }
    }

    private func setRepText(_ ex: WorkoutExercise) -> String {
        var parts: [String] = []
        if let s = ex.sets, let r = ex.reps { parts.append("\(s) × \(r)") }
        if let w = ex.weightKg, w > 0 { parts.append(String(format: "%.0f kg", w)) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Nutrition detail

struct NutritionDetailView: View {
    @State private var meals: [NutritionLog] = []
    @State private var target: NutritionTarget = .default
    @State private var showTargets = false

    private var summary: NutritionSummary { NutritionSummary(logs: meals) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack {
                    Text("Nutrition").font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Button { showTargets = true } label: {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.Palette.chip))
                    }
                }

                LivaCard {
                    VStack(spacing: 16) {
                        HStack(spacing: 18) {
                            ZStack {
                                ProgressRing(progress: target.calorieTarget > 0 ? Double(summary.calories)/Double(target.calorieTarget) : 0, size: 120)
                                VStack(spacing: 0) {
                                    Text(summary.calories.formatted()).font(.system(size: 24, weight: .semibold))
                                    Text("/ \(target.calorieTarget.formatted())").font(.system(size: 12))
                                        .foregroundStyle(Theme.Palette.inkSecondary)
                                }
                            }
                            VStack(spacing: 14) {
                                MacroBar(label: "Protein", value: summary.protein, target: target.proteinTarget)
                                MacroBar(label: "Carbs", value: summary.carbs, target: target.carbsTarget)
                                MacroBar(label: "Fats", value: summary.fats, target: target.fatsTarget)
                            }
                        }
                    }
                }

                LivaCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Today's meals")
                        if meals.isEmpty {
                            Text("Nothing logged yet today.").font(.system(size: 14))
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        } else {
                            ForEach(meals) { meal in
                                HStack(spacing: 12) {
                                    Image(systemName: meal.meal.symbol).foregroundStyle(Theme.Palette.accent)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(meal.name).font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Theme.Palette.ink)
                                        Text("P\(meal.proteinG) · C\(meal.carbsG) · F\(meal.fatsG)")
                                            .font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary)
                                    }
                                    Spacer()
                                    Text("\(meal.calories) cal").font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.ink)
                                }
                                if meal.id != meals.last?.id { Divider().overlay(Theme.Palette.divider) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTargets, onDismiss: { Task { await load() } }) {
            NutritionTargetsView(target: target)
        }
        .task { await load() }
    }

    private func load() async {
        meals = (try? await TrackingService.meals()) ?? []
        if let t = try? await TrackingService.target() { target = t }
    }
}

struct NutritionTargetsView: View {
    let target: NutritionTarget
    @Environment(\.dismiss) private var dismiss
    @State private var cal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fats = ""
    @State private var saving = false

    var body: some View {
        LogSheet(title: "Daily Targets", canSave: true, isSaving: saving) {
            save()
        } content: {
            NumberField(label: "Calorie target", text: $cal, unit: "cal")
            NumberField(label: "Protein target", text: $protein, unit: "g")
            NumberField(label: "Carbs target", text: $carbs, unit: "g")
            NumberField(label: "Fats target", text: $fats, unit: "g")
        }
        .onAppear {
            cal = String(target.calorieTarget); protein = String(target.proteinTarget)
            carbs = String(target.carbsTarget); fats = String(target.fatsTarget)
        }
    }

    private func save() {
        saving = true
        let t = NutritionTarget(
            profileID: nil,
            calorieTarget: Int(cal) ?? target.calorieTarget,
            proteinTarget: Int(protein) ?? target.proteinTarget,
            carbsTarget: Int(carbs) ?? target.carbsTarget,
            fatsTarget: Int(fats) ?? target.fatsTarget
        )
        Task { try? await TrackingService.saveTarget(t); saving = false; dismiss() }
    }
}
