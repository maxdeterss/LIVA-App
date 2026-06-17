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

    init(
        healthData: HealthDataSource,
        queue: OfflineQueue,
        goals: GoalServiceProtocol,
        workouts: WorkoutServiceProtocol,
        biometrics: BiometricServiceProtocol,
        body: BodyMetricServiceProtocol,
        water: WaterServiceProtocol,
        nutrition: NutritionReadServiceProtocol
    ) {
        self.healthData = healthData
        self.queue = queue
        self.goals = goals
        self.workouts = workouts
        self.biometrics = biometrics
        self.body = body
        self.water = water
        self.nutrition = nutrition
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
            nutrition: NutritionReadService()
        )
    }

    /// Replay any writes queued while offline.
    func flushOfflineQueue() async {
        await queue.flush()
    }
}
