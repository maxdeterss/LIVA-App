import SwiftUI
import Observation

@MainActor
@Observable
final class HealthDashboardModel {
    var day = Calendar.current.startOfDay(for: Date())
    var biometrics: [BiometricKind: Biometric] = [:]
    var steps = 0
    var activeCalories = 0
    var goal = HealthGoal.default
    var nutrition = HealthMath.MacroTotals()
    var workouts: [Workout] = []
    var waterML = 0
    var loading = false

    var latestWorkout: Workout? { workouts.first }
    var isToday: Bool { Calendar.current.isDateInToday(day) }

    var dayWorkoutSteps: Int {
        isToday ? steps : 0
    }
    var dayWorkoutCalories: Int {
        let logged = workouts.compactMap(\.totalCalories).reduce(0, +)
        return isToday ? max(activeCalories, logged) : logged
    }

    func load(_ env: HealthEnvironment) async {
        loading = true
        defer { loading = false }

        async let deviceBio = env.healthData.latestBiometrics()
        async let deviceSteps = env.healthData.todaySteps()
        async let deviceCals = env.healthData.todayActiveCalories()
        async let manual = env.biometrics.latestManual()
        async let goalV = env.goals.current()
        async let dayWorkouts = env.workouts.forDay(day)
        async let entries = env.nutrition.entries(on: day)
        async let water = env.water.total(on: day)

        var merged = HealthMath.latest((try? await manual) ?? [])
        if isToday {
            for d in await deviceBio {
                if let cur = merged[d.metric] {
                    if d.recordedAt >= cur.recordedAt { merged[d.metric] = d }
                } else {
                    merged[d.metric] = d
                }
            }
            steps = (await deviceSteps) ?? 0
            activeCalories = (await deviceCals) ?? 0
        } else {
            steps = 0
            activeCalories = 0
        }
        biometrics = merged
        goal = (try? await goalV) ?? .default
        workouts = (try? await dayWorkouts) ?? []
        nutrition = HealthMath.totals((try? await entries) ?? [])
        waterML = (try? await water) ?? 0
    }

    func select(_ newDay: Date, env: HealthEnvironment) {
        day = Calendar.current.startOfDay(for: newDay)
        Task { await load(env) }
    }

    // MARK: Display helpers

    func value(for metric: BiometricKind) -> String {
        guard let b = biometrics[metric] else { return "—" }
        switch metric {
        case .spo2: return "\(Int(b.value))%"
        case .bodyTemp: return "\(trim(b.value))°"
        case .sleepHours: return trim(b.value)
        default: return "\(Int(b.value))"
        }
    }

    private func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    var calorieProgress: Double {
        HealthMath.progress(nutrition.calories, target: goal.calorieTarget ?? 2000)
    }
}
