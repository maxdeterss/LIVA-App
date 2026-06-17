import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(HealthEnvironment.self) private var env
    @State private var model = HealthDashboardModel()
    @State private var sheet: HealthSheet?

    enum HealthSheet: Identifiable {
        case workout, biometrics, weight, meal
        var id: Int { hashValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                WeekStripSelectable(selected: model.day) { model.select($0, env: env) }
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
        .refreshable { await model.load(env) }
        .task { await model.load(env) }
        .sheet(item: $sheet, onDismiss: { Task { await model.load(env) } }) { which in
            switch which {
            case .workout:    LogWorkoutView()
            case .biometrics: LogBiometricView()
            case .weight:     LogWeightView()
            case .meal:       MealLoggerStub()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(url: session.profile?.avatarURL, initials: session.profile?.initials ?? "L", size: 44)
            BrandHeader(secondary: "health", size: 28)
            Spacer(minLength: 0)
            circleButton("calendar") { model.select(Date(), env: env) }
            circleButton("applewatch") {}
            circleButton("plus") { sheet = .workout }
        }
        .padding(.top, 4)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 40, height: 40).background(Circle().fill(Theme.Palette.chip))
        }.buttonStyle(.plain)
    }

    // MARK: Biometrics

    private var biometricsCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionLabel("Biometrics")
                    Spacer()
                    NavigationLink { BiometricsOverviewView() } label: { ViewAllLabel() }
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(BiometricKind.dashboard) { metric in
                        NavigationLink {
                            BiometricDetailView(metric: metric)
                        } label: {
                            MetricChip(symbol: metric.symbol,
                                       value: model.value(for: metric),
                                       label: metric.shortLabel)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Workouts

    private var workoutsCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionLabel("Workouts")
                    Spacer()
                    NavigationLink { WorkoutHistoryView() } label: { ViewAllLabel() }
                }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.latestWorkout?.displayTitle ?? "No workout yet")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
                        Text(model.latestWorkout?.type.title.uppercased() ?? "TAP + TO LOG")
                            .font(.system(size: 12, weight: .medium)).tracking(0.5)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                        if let dur = model.latestWorkout?.durationMinutes {
                            Text("\(dur) MIN").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                    Spacer()
                    Divider().frame(height: 70).overlay(Theme.Palette.divider)
                    VStack(alignment: .leading, spacing: 12) {
                        bigStat(model.dayWorkoutSteps.formatted(), "STEPS")
                        bigStat(model.dayWorkoutCalories.formatted(), "CAL")
                    }
                    BodyMap().frame(width: 52, height: 92)
                    Button { sheet = .workout } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink).frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.chip))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    // MARK: Nutrition

    private var nutritionCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionLabel("Nutrition")
                    Spacer()
                    NavigationLink { NutritionOverviewView() } label: { ViewAllLabel() }
                }
                HStack(spacing: 18) {
                    ZStack {
                        ProgressRing(progress: model.calorieProgress, size: 132)
                        VStack(spacing: 0) {
                            Text(model.nutrition.calories.formatted())
                                .font(.system(size: 26, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
                            Text("/ \((model.goal.calorieTarget ?? 0).formatted())")
                                .font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
                            Text("CAL").font(.system(size: 10, weight: .semibold)).tracking(1)
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                    VStack(spacing: 16) {
                        SegmentedProgressBar(label: "Protein", value: model.nutrition.protein, target: model.goal.proteinG ?? 0)
                        SegmentedProgressBar(label: "Carbs", value: model.nutrition.carbs, target: model.goal.carbsG ?? 0)
                        SegmentedProgressBar(label: "Fats", value: model.nutrition.fats, target: model.goal.fatsG ?? 0)
                    }
                    Button { sheet = .meal } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink).frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.chip))
                    }.buttonStyle(.plain)
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
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Theme.Palette.ink)
                Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.surfaceRaised))
        }.buttonStyle(.plain)
    }
}

// MARK: - Week strip (selectable)

struct WeekStripSelectable: View {
    let selected: Date
    let onSelect: (Date) -> Void

    private var days: [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        guard let interval = cal.dateInterval(of: .weekOfYear, for: selected) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private let symbols = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    var body: some View {
        LivaCard(padding: 16) {
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { idx, date in
                    let cal = Calendar.current
                    let isSelected = cal.isDate(date, inSameDayAs: selected)
                    Button { onSelect(date) } label: {
                        VStack(spacing: 6) {
                            Text(symbols[idx]).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.Palette.inkSecondary)
                            Text("\(cal.component(.day, from: date))")
                                .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(Theme.Palette.ink)
                            Capsule().fill(isSelected ? Theme.Palette.ink : .clear).frame(width: 16, height: 3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Body figure

struct BodyMap: View {
    var body: some View {
        Image(systemName: "figure.stand").resizable().scaledToFit()
            .foregroundStyle(Theme.Palette.inkTertiary)
    }
}

// MARK: - Meal logger stub (Phase 3)

struct MealLoggerStub: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                EmptyStateView(systemName: "fork.knife",
                               title: "Nutrition logging is coming",
                               message: "Search, barcode scan, and snap-a-photo AI meal logging land in Phase 3. The calorie ring above already reflects anything logged.")
            }
            .navigationTitle("Log Meal").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
        }
    }
}
