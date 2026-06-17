import SwiftUI
import Charts

// MARK: - Per-metric detail with chart

struct BiometricDetailView: View {
    let metric: BiometricKind
    @Environment(HealthEnvironment.self) private var env

    enum Range: String, CaseIterable, Identifiable {
        case week = "W", month = "M", quarter = "3M"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : self == .month ? 30 : 90 }
    }

    @State private var range: Range = .week
    @State private var points: [Biometric] = []
    @State private var loading = true

    private var values: [Double] { points.map(\.value) }
    private var stats: HealthMath.Stats? { HealthMath.stats(values) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(metric.title).font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.Palette.ink)

                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                LivaCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if let s = stats {
                            HStack {
                                stat("MIN", s.min); Spacer()
                                stat("AVG", s.avg); Spacer()
                                stat("MAX", s.max)
                            }
                        }
                        chart
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task(id: range) { await load() }
    }

    private var chart: some View {
        Group {
            if loading {
                ProgressView().tint(Theme.Palette.accent).frame(height: 200).frame(maxWidth: .infinity)
            } else if points.isEmpty {
                Text("No data for this range yet.").font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.inkSecondary).frame(height: 200)
            } else {
                Chart(points) { p in
                    AreaMark(x: .value("Date", p.recordedAt), y: .value(metric.title, p.value))
                        .foregroundStyle(LinearGradient(colors: [Theme.Palette.accent.opacity(0.25), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", p.recordedAt), y: .value(metric.title, p.value))
                        .foregroundStyle(Theme.Palette.accentDeep)
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 200)
            }
        }
    }

    private func stat(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text(format(value)).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    private func format(_ v: Double) -> String {
        (metric == .sleepHours || metric == .bodyTemp) ? String(format: "%.1f", v) : String(Int(v.rounded()))
    }

    private func load() async {
        loading = true
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -range.days, to: to)!
        let device = await env.healthData.series(metric, from: from, to: to)
        let manual = (try? await env.biometrics.series(metric, from: from, to: to)) ?? []
        points = (device + manual).sorted { $0.recordedAt < $1.recordedAt }
        loading = false
    }
}

// MARK: - Biometrics overview grid

struct BiometricsOverviewView: View {
    @Environment(HealthEnvironment.self) private var env
    @State private var latest: [BiometricKind: Biometric] = [:]

    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Biometrics").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.Palette.ink)
                LivaCard {
                    LazyVGrid(columns: cols, spacing: 18) {
                        ForEach(BiometricKind.dashboard) { m in
                            NavigationLink { BiometricDetailView(metric: m) } label: {
                                MetricChip(symbol: m.symbol, value: display(m), label: m.title, iconSize: 42)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen).padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task {
            var merged = HealthMath.latest((try? await env.biometrics.latestManual()) ?? [])
            for d in await env.healthData.latestBiometrics() where merged[d.metric] == nil {
                merged[d.metric] = d
            }
            latest = merged
        }
    }

    private func display(_ m: BiometricKind) -> String {
        guard let b = latest[m] else { return "—" }
        switch m {
        case .spo2: return "\(Int(b.value))%"
        case .bodyTemp: return String(format: "%.1f°", b.value)
        case .sleepHours: return String(format: "%.1f", b.value)
        default: return "\(Int(b.value))"
        }
    }
}

// MARK: - Workout history

struct WorkoutHistoryView: View {
    @Environment(HealthEnvironment.self) private var env
    @State private var workouts: [Workout] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Workouts").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.Palette.ink)
                if loading {
                    ProgressView().tint(Theme.Palette.accent).frame(maxWidth: .infinity).padding(.top, 40)
                } else if workouts.isEmpty {
                    EmptyStateView(systemName: "dumbbell", title: "No workouts logged",
                                   message: "Tap + on the dashboard to log your first session.")
                } else {
                    ForEach(workouts) { WorkoutRow(workout: $0) }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen).padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task {
            workouts = (try? await env.workouts.recent(limit: 30)) ?? []
            loading = false
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        LivaCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconCircle(systemName: workout.type.symbol, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.displayTitle).font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                        Text(workout.startedAt, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        if let d = workout.durationMinutes { Text("\(d) min").font(.system(size: 14, weight: .medium)) }
                        if let c = workout.totalCalories { Text("\(c) cal").font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary) }
                    }
                }
                if let sets = workout.sets, !sets.isEmpty {
                    Divider().overlay(Theme.Palette.divider)
                    ForEach(sets.sorted { $0.setIndex < $1.setIndex }) { s in
                        HStack {
                            Text(s.exerciseName).font(.system(size: 14)).foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            Text(setText(s)).font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                }
            }
        }
    }

    private func setText(_ s: StrengthSet) -> String {
        var parts: [String] = []
        if let r = s.reps { parts.append("\(s.reps != nil ? "" : "")\(r) reps") }
        if let w = s.weightKg, w > 0 { parts.append(String(format: "%.0f kg", w)) }
        if let rpe = s.rpe, rpe > 0 { parts.append("RPE \(String(format: "%.0f", rpe))") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Nutrition overview (+ water)

struct NutritionOverviewView: View {
    @Environment(HealthEnvironment.self) private var env
    @State private var entries: [NutritionEntry] = []
    @State private var goal = HealthGoal.default
    @State private var waterML = 0

    private var totals: HealthMath.MacroTotals { HealthMath.totals(entries) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Nutrition").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.Palette.ink)

                LivaCard {
                    HStack(spacing: 18) {
                        ZStack {
                            ProgressRing(progress: HealthMath.progress(totals.calories, target: goal.calorieTarget ?? 2000), size: 120)
                            VStack(spacing: 0) {
                                Text(totals.calories.formatted()).font(.system(size: 24, weight: .semibold))
                                Text("/ \((goal.calorieTarget ?? 0).formatted())").font(.system(size: 12))
                                    .foregroundStyle(Theme.Palette.inkSecondary)
                            }
                        }
                        VStack(spacing: 14) {
                            SegmentedProgressBar(label: "Protein", value: totals.protein, target: goal.proteinG ?? 0)
                            SegmentedProgressBar(label: "Carbs", value: totals.carbs, target: goal.carbsG ?? 0)
                            SegmentedProgressBar(label: "Fats", value: totals.fats, target: goal.fatsG ?? 0)
                        }
                    }
                }

                waterCard

                LivaCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Today's meals")
                        if entries.isEmpty {
                            Text("Nothing logged yet. Full food logging arrives in Phase 3.")
                                .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                        } else {
                            ForEach(entries) { e in
                                HStack {
                                    Image(systemName: e.meal.symbol).foregroundStyle(Theme.Palette.accent).frame(width: 24)
                                    Text(e.customName ?? e.meal.title).font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.Palette.ink)
                                    Spacer()
                                    Text("\(e.calories) cal").font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.ink)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen).padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var waterCard: some View {
        LivaCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Water")
                HStack {
                    Text("\(waterML) / \(goal.waterGoalML ?? 3000) ml")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Button {
                        Task { try? await env.water.add(ml: 250); await load() }
                    } label: {
                        Label("250 ml", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.tabBarText)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(Theme.Palette.ink))
                    }.buttonStyle(.plain)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.track)
                        Capsule().fill(Theme.Palette.accent)
                            .frame(width: geo.size.width * HealthMath.progress(waterML, target: goal.waterGoalML ?? 3000))
                    }
                }.frame(height: 8)
            }
        }
    }

    private func load() async {
        entries = (try? await env.nutrition.entries(on: Date())) ?? []
        goal = (try? await env.goals.current()) ?? .default
        waterML = (try? await env.water.total(on: Date())) ?? 0
    }
}
