import Foundation

// MARK: - Goal (versioned daily targets)

struct HealthGoal: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var effectiveDate: Date
    var calorieTarget: Int? = nil
    var proteinG: Int? = nil
    var carbsG: Int? = nil
    var fatsG: Int? = nil
    var stepGoal: Int? = nil
    var sleepGoalHours: Double? = nil
    var waterGoalML: Int? = nil
    var activeMinutesWeekly: Int? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case effectiveDate = "effective_date"
        case calorieTarget = "calorie_target"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
        case stepGoal = "step_goal"
        case sleepGoalHours = "sleep_goal_hours"
        case waterGoalML = "water_goal_ml"
        case activeMinutesWeekly = "active_minutes_weekly"
    }

    static let `default` = HealthGoal(
        effectiveDate: Date(), calorieTarget: 2900, proteinG: 200, carbsG: 350,
        fatsG: 100, stepGoal: 10000, sleepGoalHours: 8, waterGoalML: 3000,
        activeMinutesWeekly: 150
    )
}

// MARK: - Workout

struct Workout: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var type: WorkoutKind
    var source: MetricSource = .manual
    var title: String? = nil
    var startedAt: Date
    var endedAt: Date? = nil
    var durationS: Int? = nil
    var totalCalories: Int? = nil
    var avgHR: Int? = nil
    var maxHR: Int? = nil
    var notes: String? = nil
    var privacy: Privacy = .followers
    var sets: [StrengthSet]? = nil

    enum CodingKeys: String, CodingKey {
        case id, type, source, title, notes, privacy
        case userID = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationS = "duration_s"
        case totalCalories = "total_calories"
        case avgHR = "avg_hr"
        case maxHR = "max_hr"
        case sets = "strength_sets"
    }

    var displayTitle: String { title ?? type.title }
    var durationMinutes: Int? { durationS.map { $0 / 60 } }
}

struct StrengthSet: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var workoutID: UUID? = nil
    var exerciseID: UUID? = nil
    var exerciseName: String
    var setIndex: Int
    var reps: Int? = nil
    var weightKg: Double? = nil
    var rpe: Double? = nil
    var restS: Int? = nil

    enum CodingKeys: String, CodingKey {
        case id, reps, rpe
        case workoutID = "workout_id"
        case exerciseID = "exercise_id"
        case exerciseName = "exercise_name"
        case setIndex = "set_index"
        case weightKg = "weight_kg"
        case restS = "rest_s"
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var equipment: String?

    enum CodingKeys: String, CodingKey {
        case id, name, equipment
        case muscleGroup = "muscle_group"
    }
}

// MARK: - Biometric

struct Biometric: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var recordedAt: Date
    var metric: BiometricKind
    var value: Double
    var unit: String? = nil
    var source: MetricSource = .manual

    enum CodingKeys: String, CodingKey {
        case id, metric, value, unit, source
        case userID = "user_id"
        case recordedAt = "recorded_at"
    }
}

// MARK: - Body metric

struct BodyMetric: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var recordedAt: Date
    var weightKg: Double? = nil
    var bodyFatPct: Double? = nil
    var leanMassKg: Double? = nil
    var waistCm: Double? = nil
    var hipCm: Double? = nil
    var chestCm: Double? = nil
    var armCm: Double? = nil
    var source: MetricSource = .manual

    enum CodingKeys: String, CodingKey {
        case id, source
        case userID = "user_id"
        case recordedAt = "recorded_at"
        case weightKg = "weight_kg"
        case bodyFatPct = "body_fat_pct"
        case leanMassKg = "lean_mass_kg"
        case waistCm = "waist_cm"
        case hipCm = "hip_cm"
        case chestCm = "chest_cm"
        case armCm = "arm_cm"
    }
}

// MARK: - Water

struct WaterLog: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var recordedAt: Date
    var amountML: Int
    var source: MetricSource = .manual

    enum CodingKeys: String, CodingKey {
        case id, source
        case userID = "user_id"
        case recordedAt = "recorded_at"
        case amountML = "amount_ml"
    }
}

// MARK: - Nutrition (Phase 1 read model for the ring)

struct NutritionEntry: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var customName: String? = nil
    var meal: MealType
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatsG: Int
    var loggedOn: Date

    enum CodingKeys: String, CodingKey {
        case id, meal, calories
        case userID = "user_id"
        case customName = "custom_name"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
        case loggedOn = "logged_on"
    }
}
