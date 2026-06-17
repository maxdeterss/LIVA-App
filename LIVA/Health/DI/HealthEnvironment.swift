import SwiftUI
import Observation

/// Dependency container for the Health module. Injected via the SwiftUI
/// environment so views/view-models receive mockable services (testability).
@MainActor
@Observable
final class HealthEnvironment {
    let healthData: HealthDataSource
    let queue: OfflineQueue
    let goals: GoalServiceProtocol
    let workouts: WorkoutServiceProtocol
    let biometrics: BiometricServiceProtocol
    let body: BodyMetricServiceProtocol
    let water: WaterServiceProtocol
    let nutrition: NutritionReadServiceProtocol
    let foodSearch: FoodSearchServiceProtocol
    let ai: AINutritionServiceProtocol
    let nutritionLog: NutritionLogServiceProtocol

    init(
        healthData: HealthDataSource,
        queue: OfflineQueue,
        goals: GoalServiceProtocol,
        workouts: WorkoutServiceProtocol,
        biometrics: BiometricServiceProtocol,
        body: BodyMetricServiceProtocol,
        water: WaterServiceProtocol,
        nutrition: NutritionReadServiceProtocol,
        foodSearch: FoodSearchServiceProtocol,
        ai: AINutritionServiceProtocol,
        nutritionLog: NutritionLogServiceProtocol
    ) {
        self.healthData = healthData
        self.queue = queue
        self.goals = goals
        self.workouts = workouts
        self.biometrics = biometrics
        self.body = body
        self.water = water
        self.nutrition = nutrition
        self.foodSearch = foodSearch
        self.ai = ai
        self.nutritionLog = nutritionLog
    }

    /// Production wiring.
    static func live() -> HealthEnvironment {
        let queue = OfflineQueue()
        let writer = RemoteWriter(queue: queue)
        return HealthEnvironment(
            healthData: HealthDataSourceFactory.make(),
            queue: queue,
            goals: GoalService(writer: writer),
            workouts: WorkoutService(writer: writer),
            biometrics: BiometricService(writer: writer),
            body: BodyMetricService(writer: writer),
            water: WaterService(writer: writer),
            nutrition: NutritionReadService(),
            foodSearch: FoodSearchService(),
            ai: AINutritionService(),
            nutritionLog: NutritionLogService(writer: writer)
        )
    }

    /// Replay any writes queued while offline.
    func flushOfflineQueue() async {
        await queue.flush()
    }
}
