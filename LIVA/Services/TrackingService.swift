import Foundation
import Supabase

/// All personal tracking: weight, workouts, biometrics and nutrition.
enum TrackingService {

    private static func requireUID() throws -> UUID {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        return uid
    }

    // MARK: Weight

    static func logWeight(weightKg: Double, on date: Date = Date(), note: String?) async throws {
        let uid = try requireUID()
        struct Row: Encodable {
            let profile_id: String; let weight_kg: Double
            let logged_on: String; let note: String?
        }
        try await LIVA.supabase.from("weight_logs")
            .upsert(Row(profile_id: uid.uuidString, weight_kg: weightKg,
                        logged_on: date.pgDateString, note: note),
                    onConflict: "profile_id,logged_on")
            .execute()
    }

    static func recentWeights(limit: Int = 30) async throws -> [WeightLog] {
        let uid = try requireUID()
        let data = try await LIVA.supabase.from("weight_logs").select()
            .eq("profile_id", value: uid.uuidString)
            .order("logged_on", ascending: false)
            .limit(limit)
            .execute().data
        return try AppJSON.decoder.decode([WeightLog].self, from: data)
    }

    // MARK: Workouts

    /// Inserts a workout plus its exercises.
    static func logWorkout(_ workout: WorkoutLog) async throws {
        let uid = try requireUID()
        struct Row: Encodable {
            let profile_id: String; let title: String; let type: String
            let duration_min: Int?; let calories: Int?
            let distance_miles: Double?; let steps: Int?; let notes: String?
        }
        struct Inserted: Decodable { let id: UUID }
        let data = try await LIVA.supabase.from("workout_logs")
            .insert(Row(profile_id: uid.uuidString, title: workout.title, type: workout.type.rawValue,
                        duration_min: workout.durationMin, calories: workout.calories,
                        distance_miles: workout.distanceMiles, steps: workout.steps, notes: workout.notes))
            .select("id").single().execute().data
        let inserted = try AppJSON.decoder.decode(Inserted.self, from: data)

        if let exercises = workout.exercises, !exercises.isEmpty {
            struct ExRow: Encodable {
                let workout_log_id: String; let name: String
                let sets: Int?; let reps: Int?; let weight_kg: Double?; let position: Int
            }
            let rows = exercises.enumerated().map { idx, e in
                ExRow(workout_log_id: inserted.id.uuidString, name: e.name,
                      sets: e.sets, reps: e.reps, weight_kg: e.weightKg, position: idx)
            }
            try await LIVA.supabase.from("workout_exercises").insert(rows).execute()
        }
    }

    static func recentWorkouts(limit: Int = 20) async throws -> [WorkoutLog] {
        let uid = try requireUID()
        let data = try await LIVA.supabase.from("workout_logs")
            .select("*, workout_exercises(*)")
            .eq("profile_id", value: uid.uuidString)
            .order("logged_at", ascending: false)
            .limit(limit)
            .execute().data
        return try AppJSON.decoder.decode([WorkoutLog].self, from: data)
    }

    /// Steps + calories summed across today's workouts (for the dashboard card).
    static func todaySummary() async throws -> (steps: Int, calories: Int, latest: WorkoutLog?) {
        let workouts = try await recentWorkouts(limit: 10)
        let cal = Calendar.current
        let today = workouts.filter { cal.isDateInToday($0.loggedAt) }
        let steps = today.compactMap(\.steps).reduce(0, +)
        let calories = today.compactMap(\.calories).reduce(0, +)
        return (steps, calories, today.first)
    }

    // MARK: Daily biometrics

    static func metric(on day: Date = Date()) async throws -> DailyMetric? {
        let uid = try requireUID()
        let data = try await LIVA.supabase.from("daily_metrics").select()
            .eq("profile_id", value: uid.uuidString)
            .eq("day", value: day.pgDateString)
            .execute().data
        return try AppJSON.decoder.decode([DailyMetric].self, from: data).first
    }

    static func saveMetric(
        day: Date = Date(),
        steps: Int?, hrv: Int?, restingHR: Int?,
        sleepHours: Double?, spo2: Int?, tempF: Double?
    ) async throws {
        let uid = try requireUID()
        struct Row: Encodable {
            let profile_id: String; let day: String
            let steps: Int?; let hrv: Int?; let resting_hr: Int?
            let sleep_hours: Double?; let spo2: Int?; let temp_f: Double?
        }
        try await LIVA.supabase.from("daily_metrics")
            .upsert(Row(profile_id: uid.uuidString, day: day.pgDateString,
                        steps: steps, hrv: hrv, resting_hr: restingHR,
                        sleep_hours: sleepHours, spo2: spo2, temp_f: tempF),
                    onConflict: "profile_id,day")
            .execute()
    }

    // MARK: Nutrition

    static func target() async throws -> NutritionTarget {
        let uid = try requireUID()
        let data = try await LIVA.supabase.from("nutrition_targets").select()
            .eq("profile_id", value: uid.uuidString)
            .execute().data
        if let existing = try AppJSON.decoder.decode([NutritionTarget].self, from: data).first {
            return existing
        }
        return .default
    }

    static func saveTarget(_ t: NutritionTarget) async throws {
        let uid = try requireUID()
        struct Row: Encodable {
            let profile_id: String; let calorie_target: Int
            let protein_target: Int; let carbs_target: Int; let fats_target: Int
        }
        try await LIVA.supabase.from("nutrition_targets")
            .upsert(Row(profile_id: uid.uuidString, calorie_target: t.calorieTarget,
                        protein_target: t.proteinTarget, carbs_target: t.carbsTarget,
                        fats_target: t.fatsTarget),
                    onConflict: "profile_id")
            .execute()
    }

    static func logMeal(_ meal: NutritionLog) async throws {
        let uid = try requireUID()
        struct Row: Encodable {
            let profile_id: String; let name: String; let meal: String
            let calories: Int; let protein_g: Int; let carbs_g: Int
            let fats_g: Int; let logged_on: String
        }
        try await LIVA.supabase.from("nutrition_logs")
            .insert(Row(profile_id: uid.uuidString, name: meal.name, meal: meal.meal.rawValue,
                        calories: meal.calories, protein_g: meal.proteinG, carbs_g: meal.carbsG,
                        fats_g: meal.fatsG, logged_on: meal.loggedOn.pgDateString))
            .execute()
    }

    static func meals(on day: Date = Date()) async throws -> [NutritionLog] {
        let uid = try requireUID()
        let data = try await LIVA.supabase.from("nutrition_logs").select()
            .eq("profile_id", value: uid.uuidString)
            .eq("logged_on", value: day.pgDateString)
            .order("logged_at", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([NutritionLog].self, from: data)
    }
}
