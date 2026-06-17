import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = HealthViewModel()
    @State private var sheet: HealthSheet?

    enum HealthSheet: Identifiable {
        case weight, workout, biometrics, meal
        var id: Int { hashValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                WeekStrip()
                biometricsCard
                workoutsCard
                nutritionCard
                addDataCard
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationBarHidden(true)
        .refreshable { await model.load() }
        .task { await model.load() }
        .sheet(item: $sheet, onDismiss: { Task { await model.load() } }) { which in
            switch which {
            case .weight:     LogWeightView()
            case .workout:    LogWorkoutView()
            case .biometrics: LogBiometricsView(existing: model.metric)
            case .meal:       LogMealView()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(url: session.profile?.avatarURL, initials: session.profile?.initials ?? "L", size: 44)
            BrandHeader(secondary: "health", size: 28)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                circleButton("calendar") {}
                circleButton("applewatch") {}
                circleButton("plus") { sheet = .meal }
            }
        }
        .padding(.top, 4)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.Palette.chip))
        }
        .buttonStyle(.plain)
    }

    // MARK: Biometrics

    private var biometricsCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack { SectionLabel("Biometrics"); Spacer()
                    NavigationLink { BiometricsDetailView() } label: { ViewAllLabel() } }
                HStack(alignment: .top, spacing: 0) {
                    metricCell("heart.text.square", value: model.metric?.hrv.map(String.init) ?? "—", unit: "HRV")
                    metricCell("heart", value: model.metric?.restingHR.map(String.init) ?? "—", unit: "RHR")
                    metricCell("moon.zzz", value: model.metric?.sleepHours.map { trimmed($0) } ?? "—", unit: "HRS\nSLEEP")
                    metricCell("drop", value: model.metric?.spo2.map { "\($0)%" } ?? "—", unit: "SPO2")
                    metricCell("thermometer.medium", value: model.metric?.tempF.map { "\(trimmed($0))°" } ?? "—", unit: "TEMP")
                }
            }
        }
    }

    private func metricCell(_ icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 8) {
            IconCircle(systemName: icon, size: 46)
            Text(value).font(.statNumber(20)).foregroundStyle(Theme.Palette.ink)
            Text(unit).font(.system(size: 10, weight: .medium)).tracking(0.5)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Workouts

    private var workoutsCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack { SectionLabel("Workouts"); Spacer()
                    NavigationLink { WorkoutsListView() } label: { ViewAllLabel() } }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.latestWorkout?.title ?? "No workout yet")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.Palette.ink)
                            Text(model.latestWorkout?.type.title.uppercased() ?? "TAP + TO LOG")
                                .font(.system(size: 12, weight: .medium)).tracking(0.5)
                                .foregroundStyle(Theme.Palette.inkSecondary)
                            if let dur = model.latestWorkout?.durationMin {
                                Text("\(dur) MIN").font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.Palette.inkSecondary)
                            }
                        }
                    }
                    Spacer()
                    Divider().frame(height: 70).overlay(Theme.Palette.divider)
                    VStack(alignment: .leading, spacing: 12) {
                        bigStat(value: model.workoutSteps.formatted(), label: "STEPS")
                        bigStat(value: model.workoutCalories.formatted(), label: "CAL")
                    }
                    BodyMap().frame(width: 56, height: 96)
                    Button { sheet = .workout } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Palette.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bigStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    // MARK: Nutrition

    private var nutritionCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack { SectionLabel("Nutrition"); Spacer()
                    NavigationLink { NutritionDetailView() } label: { ViewAllLabel() } }
                HStack(spacing: 18) {
                    ZStack {
                        ProgressRing(progress: model.calorieProgress, size: 132)
                        VStack(spacing: 0) {
                            Text(model.nutrition.calories.formatted())
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Theme.Palette.ink)
                            Text("/ \(model.target.calorieTarget.formatted())")
                                .font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
                            Text("CAL").font(.system(size: 10, weight: .semibold)).tracking(1)
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                    VStack(spacing: 16) {
                        MacroBar(label: "Protein", value: model.nutrition.protein, target: model.target.proteinTarget)
                        MacroBar(label: "Carbs", value: model.nutrition.carbs, target: model.target.carbsTarget)
                        MacroBar(label: "Fats", value: model.nutrition.fats, target: model.target.fatsTarget)
                    }
                    Button { sheet = .meal } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Palette.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Add data

    private var addDataCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel("Add data for today")
                    Text("Log a workout, meal, or update your biometrics.")
                        .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                }
                HStack(spacing: 10) {
                    quickAdd("dumbbell", "WORKOUT") { sheet = .workout }
                    quickAdd("fork.knife", "MEAL") { sheet = .meal }
                    quickAdd("heart", "BIOMETRICS") { sheet = .biometrics }
                    quickAdd("scalemass", "WEIGHT") { sheet = .weight }
                }
            }
        }
    }

    private func quickAdd(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.Palette.ink)
                Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Palette.surfaceRaised))
        }
        .buttonStyle(.plain)
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Week strip

/// Mon–Sun strip with today underlined, matching the mockup.
struct WeekStrip: View {
    private let days: [(label: String, day: Int, isToday: Bool)] = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let today = Date()
        guard let interval = cal.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let symbols = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        return (0..<7).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return (symbols[offset], cal.component(.day, from: date), cal.isDateInToday(date))
        }
    }()

    var body: some View {
        LivaCard(padding: 16) {
            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    let d = days[i]
                    VStack(spacing: 6) {
                        Text(d.label).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.inkSecondary)
                        Text("\(d.day)").font(.system(size: 18, weight: d.isToday ? .bold : .regular))
                            .foregroundStyle(Theme.Palette.ink)
                        Capsule().fill(d.isToday ? Theme.Palette.ink : .clear)
                            .frame(width: 16, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Body map

/// Stylised front-body figure used in the workouts card.
struct BodyMap: View {
    var body: some View {
        Image(systemName: "figure.stand")
            .resizable().scaledToFit()
            .foregroundStyle(Theme.Palette.inkTertiary)
    }
}
