import Foundation

@MainActor
final class HealthViewModel: ObservableObject {
    @Published var metric: DailyMetric?
    @Published var target: NutritionTarget = .default
    @Published var meals: [NutritionLog] = []
    @Published var workoutSteps = 0
    @Published var workoutCalories = 0
    @Published var latestWorkout: WorkoutLog?
    @Published var latestWeight: WeightLog?
    @Published var isLoading = false

    var nutrition: NutritionSummary { NutritionSummary(logs: meals) }

    var calorieProgress: Double {
        target.calorieTarget > 0 ? Double(nutrition.calories) / Double(target.calorieTarget) : 0
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let metric = try? TrackingService.metric()
        async let target = try? TrackingService.target()
        async let meals = try? TrackingService.meals()
        async let summary = try? TrackingService.todaySummary()
        async let weights = try? TrackingService.recentWeights(limit: 1)

        self.metric = await metric ?? nil
        if let t = await target { self.target = t }
        self.meals = await meals ?? []
        if let s = await summary {
            workoutSteps = s.steps
            workoutCalories = s.calories
            latestWorkout = s.latest
        }
        latestWeight = (await weights ?? []).first
    }
}
