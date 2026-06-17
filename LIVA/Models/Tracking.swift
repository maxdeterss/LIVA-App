import Foundation

/// A single weight entry (`public.weight_logs`).
struct WeightLog: Codable, Identifiable, Hashable {
    var id: UUID?
    var profileID: UUID?
    var weightKg: Double
    var loggedOn: Date
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, note
        case profileID = "profile_id"
        case weightKg = "weight_kg"
        case loggedOn = "logged_on"
    }

    var weightLbs: Double { weightKg * 2.2046226218 }
}

/// A logged workout (`public.workout_logs`) with optional exercises.
struct WorkoutLog: Codable, Identifiable, Hashable {
    var id: UUID?
    var profileID: UUID?
    var title: String
    var type: WorkoutType
    var durationMin: Int?
    var calories: Int?
    var distanceMiles: Double?
    var steps: Int?
    var notes: String?
    var loggedAt: Date
    var exercises: [WorkoutExercise]?

    enum CodingKeys: String, CodingKey {
        case id, title, type, calories, steps, notes
        case profileID = "profile_id"
        case durationMin = "duration_min"
        case distanceMiles = "distance_miles"
        case loggedAt = "logged_at"
        case exercises = "workout_exercises"
    }
}

/// One exercise inside a workout (`public.workout_exercises`).
struct WorkoutExercise: Codable, Identifiable, Hashable {
    var id: UUID?
    var workoutLogID: UUID?
    var name: String
    var sets: Int?
    var reps: Int?
    var weightKg: Double?
    var position: Int

    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps, position
        case workoutLogID = "workout_log_id"
        case weightKg = "weight_kg"
    }
}

/// Daily wearable / biometric snapshot (`public.daily_metrics`).
struct DailyMetric: Codable, Identifiable, Hashable {
    var profileID: UUID?
    var day: Date
    var steps: Int?
    var hrv: Int?
    var restingHR: Int?
    var sleepHours: Double?
    var spo2: Int?
    var tempF: Double?

    var id: Date { day }

    enum CodingKeys: String, CodingKey {
        case day, steps, hrv, spo2
        case profileID = "profile_id"
        case restingHR = "resting_hr"
        case sleepHours = "sleep_hours"
        case tempF = "temp_f"
    }
}

/// The user's macro targets (`public.nutrition_targets`).
struct NutritionTarget: Codable, Hashable {
    var profileID: UUID?
    var calorieTarget: Int
    var proteinTarget: Int
    var carbsTarget: Int
    var fatsTarget: Int

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case calorieTarget = "calorie_target"
        case proteinTarget = "protein_target"
        case carbsTarget = "carbs_target"
        case fatsTarget = "fats_target"
    }

    static let `default` = NutritionTarget(
        calorieTarget: 2900, proteinTarget: 200, carbsTarget: 350, fatsTarget: 100
    )
}

/// A logged meal (`public.nutrition_logs`).
struct NutritionLog: Codable, Identifiable, Hashable {
    var id: UUID?
    var profileID: UUID?
    var name: String
    var meal: MealType
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatsG: Int
    var loggedOn: Date

    enum CodingKeys: String, CodingKey {
        case id, name, meal, calories
        case profileID = "profile_id"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
        case loggedOn = "logged_on"
    }
}

/// Rolled-up nutrition totals for a day, used by the dashboard ring.
struct NutritionSummary {
    var calories = 0
    var protein = 0
    var carbs = 0
    var fats = 0

    init() {}

    init(logs: [NutritionLog]) {
        for log in logs {
            calories += log.calories
            protein += log.proteinG
            carbs += log.carbsG
            fats += log.fatsG
        }
    }
}
