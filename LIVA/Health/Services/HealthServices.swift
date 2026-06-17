import Foundation
import Supabase

// MARK: - Protocols (DI-injected, mockable)

protocol GoalServiceProtocol: Sendable {
    func current() async throws -> HealthGoal
    func save(_ goal: HealthGoal) async throws
}

protocol WorkoutServiceProtocol: Sendable {
    func recent(limit: Int) async throws -> [Workout]
    func forDay(_ day: Date) async throws -> [Workout]
    func log(_ workout: Workout) async throws
}

protocol BiometricServiceProtocol: Sendable {
    func latestManual() async throws -> [Biometric]
    func series(_ metric: BiometricKind, from: Date, to: Date) async throws -> [Biometric]
    func log(_ biometric: Biometric) async throws
}

protocol BodyMetricServiceProtocol: Sendable {
    func recent(limit: Int) async throws -> [BodyMetric]
    func log(_ body: BodyMetric) async throws
}

protocol WaterServiceProtocol: Sendable {
    func total(on day: Date) async throws -> Int
    func add(ml: Int) async throws
}

protocol NutritionReadServiceProtocol: Sendable {
    func entries(on day: Date) async throws -> [NutritionEntry]
}

// MARK: - Shared helpers

private func uid() throws -> UUID {
    guard let id = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
    return id
}

private func dayBounds(_ day: Date) -> (start: String, end: String) {
    let cal = Calendar.current
    let start = cal.startOfDay(for: day)
    let end = cal.date(byAdding: .day, value: 1, to: start)!
    let f = ISO8601DateFormatter()
    return (f.string(from: start), f.string(from: end))
}

// MARK: - Goal

struct GoalService: GoalServiceProtocol {
    let writer: RemoteWriter

    func current() async throws -> HealthGoal {
        let id = try uid()
        let data = try await LIVA.supabase.from("goals").select()
            .eq("user_id", value: id.uuidString)
            .order("effective_date", ascending: false).limit(1)
            .execute().data
        return try AppJSON.decoder.decode([HealthGoal].self, from: data).first ?? .default
    }

    func save(_ goal: HealthGoal) async throws {
        let id = try uid()
        struct Row: Encodable, Sendable {
            let user_id: String; let effective_date: String
            let calorie_target: Int?; let protein_g: Int?; let carbs_g: Int?; let fats_g: Int?
            let step_goal: Int?; let sleep_goal_hours: Double?; let water_goal_ml: Int?
            let active_minutes_weekly: Int?
        }
        let row = Row(user_id: id.uuidString, effective_date: goal.effectiveDate.pgDateString,
                      calorie_target: goal.calorieTarget, protein_g: goal.proteinG,
                      carbs_g: goal.carbsG, fats_g: goal.fatsG, step_goal: goal.stepGoal,
                      sleep_goal_hours: goal.sleepGoalHours, water_goal_ml: goal.waterGoalML,
                      active_minutes_weekly: goal.activeMinutesWeekly)
        try await writer.upsert("goals", row, onConflict: "user_id,effective_date")
    }
}

// MARK: - Workouts

struct WorkoutService: WorkoutServiceProtocol {
    let writer: RemoteWriter

    func recent(limit: Int) async throws -> [Workout] {
        let id = try uid()
        let data = try await LIVA.supabase.from("workouts")
            .select("*, strength_sets(*)")
            .eq("user_id", value: id.uuidString)
            .order("started_at", ascending: false).limit(limit)
            .execute().data
        return try AppJSON.decoder.decode([Workout].self, from: data)
    }

    func forDay(_ day: Date) async throws -> [Workout] {
        let id = try uid()
        let b = dayBounds(day)
        let data = try await LIVA.supabase.from("workouts")
            .select("*, strength_sets(*)")
            .eq("user_id", value: id.uuidString)
            .gte("started_at", value: b.start).lt("started_at", value: b.end)
            .order("started_at", ascending: false)
            .execute().data
        return try AppJSON.decoder.decode([Workout].self, from: data)
    }

    func log(_ workout: Workout) async throws {
        let id = try uid()
        struct Row: Encodable, Sendable {
            let user_id: String; let type: String; let source: String; let title: String?
            let started_at: String; let ended_at: String?; let duration_s: Int?
            let total_calories: Int?; let avg_hr: Int?; let max_hr: Int?
            let notes: String?; let privacy: String
        }
        struct Inserted: Decodable { let id: UUID }
        let iso = ISO8601DateFormatter()
        let row = Row(user_id: id.uuidString, type: workout.type.rawValue,
                      source: workout.source.rawValue, title: workout.title,
                      started_at: iso.string(from: workout.startedAt),
                      ended_at: workout.endedAt.map { iso.string(from: $0) },
                      duration_s: workout.durationS, total_calories: workout.totalCalories,
                      avg_hr: workout.avgHR, max_hr: workout.maxHR,
                      notes: workout.notes, privacy: workout.privacy.rawValue)
        do {
            let data = try await LIVA.supabase.from("workouts").insert(row).select("id").single().execute().data
            let inserted = try AppJSON.decoder.decode(Inserted.self, from: data)
            if let sets = workout.sets, !sets.isEmpty {
                struct SetRow: Encodable, Sendable {
                    let workout_id: String; let exercise_id: String?; let exercise_name: String
                    let set_index: Int; let reps: Int?; let weight_kg: Double?; let rpe: Double?; let rest_s: Int?
                }
                let rows = sets.enumerated().map { idx, s in
                    SetRow(workout_id: inserted.id.uuidString, exercise_id: s.exerciseID?.uuidString,
                           exercise_name: s.exerciseName, set_index: idx, reps: s.reps,
                           weight_kg: s.weightKg, rpe: s.rpe, rest_s: s.restS)
                }
                try await LIVA.supabase.from("strength_sets").insert(rows).execute()
            }
        } catch {
            guard NetworkReachability.isConnectivityError(error) else { throw error }
            // Offline: queue the workout row (sets re-entered next online session).
            try await writer.insert("workouts", row)
        }
    }
}

// MARK: - Biometrics

struct BiometricService: BiometricServiceProtocol {
    let writer: RemoteWriter

    func latestManual() async throws -> [Biometric] {
        let id = try uid()
        let data = try await LIVA.supabase.from("biometrics").select()
            .eq("user_id", value: id.uuidString)
            .order("recorded_at", ascending: false).limit(50)
            .execute().data
        let all = try AppJSON.decoder.decode([Biometric].self, from: data)
        return Array(HealthMath.latest(all).values)
    }

    func series(_ metric: BiometricKind, from: Date, to: Date) async throws -> [Biometric] {
        let id = try uid()
        let f = ISO8601DateFormatter()
        let data = try await LIVA.supabase.from("biometrics").select()
            .eq("user_id", value: id.uuidString)
            .eq("metric", value: metric.rawValue)
            .gte("recorded_at", value: f.string(from: from))
            .lte("recorded_at", value: f.string(from: to))
            .order("recorded_at", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([Biometric].self, from: data)
    }

    func log(_ biometric: Biometric) async throws {
        let id = try uid()
        struct Row: Encodable, Sendable {
            let user_id: String; let recorded_at: String; let metric: String
            let value: Double; let unit: String?; let source: String
        }
        let row = Row(user_id: id.uuidString,
                      recorded_at: ISO8601DateFormatter().string(from: biometric.recordedAt),
                      metric: biometric.metric.rawValue, value: biometric.value,
                      unit: biometric.unit, source: biometric.source.rawValue)
        try await writer.insert("biometrics", row)
    }
}

// MARK: - Body metrics

struct BodyMetricService: BodyMetricServiceProtocol {
    let writer: RemoteWriter

    func recent(limit: Int) async throws -> [BodyMetric] {
        let id = try uid()
        let data = try await LIVA.supabase.from("body_metrics").select()
            .eq("user_id", value: id.uuidString)
            .order("recorded_at", ascending: false).limit(limit)
            .execute().data
        return try AppJSON.decoder.decode([BodyMetric].self, from: data)
    }

    func log(_ body: BodyMetric) async throws {
        let id = try uid()
        struct Row: Encodable, Sendable {
            let user_id: String; let recorded_at: String
            let weight_kg: Double?; let body_fat_pct: Double?; let lean_mass_kg: Double?
            let waist_cm: Double?; let hip_cm: Double?; let chest_cm: Double?; let arm_cm: Double?
            let source: String
        }
        let row = Row(user_id: id.uuidString,
                      recorded_at: ISO8601DateFormatter().string(from: body.recordedAt),
                      weight_kg: body.weightKg, body_fat_pct: body.bodyFatPct,
                      lean_mass_kg: body.leanMassKg, waist_cm: body.waistCm, hip_cm: body.hipCm,
                      chest_cm: body.chestCm, arm_cm: body.armCm, source: body.source.rawValue)
        try await writer.insert("body_metrics", row)
    }
}

// MARK: - Water

struct WaterService: WaterServiceProtocol {
    let writer: RemoteWriter

    func total(on day: Date) async throws -> Int {
        let id = try uid()
        let b = dayBounds(day)
        let data = try await LIVA.supabase.from("water_logs").select("amount_ml")
            .eq("user_id", value: id.uuidString)
            .gte("recorded_at", value: b.start).lt("recorded_at", value: b.end)
            .execute().data
        struct R: Decodable { let amount_ml: Int }
        return try AppJSON.decoder.decode([R].self, from: data).reduce(0) { $0 + $1.amount_ml }
    }

    func add(ml: Int) async throws {
        let id = try uid()
        struct Row: Encodable, Sendable {
            let user_id: String; let amount_ml: Int; let recorded_at: String; let source: String
        }
        let row = Row(user_id: id.uuidString, amount_ml: ml,
                      recorded_at: ISO8601DateFormatter().string(from: Date()), source: "manual")
        try await writer.insert("water_logs", row)
    }
}

// MARK: - Nutrition (read-only for the ring in Phase 1)

struct NutritionReadService: NutritionReadServiceProtocol {
    func entries(on day: Date) async throws -> [NutritionEntry] {
        let id = try uid()
        let data = try await LIVA.supabase.from("nutrition_logs").select()
            .eq("user_id", value: id.uuidString)
            .eq("logged_on", value: day.pgDateString)
            .order("logged_at", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([NutritionEntry].self, from: data)
    }
}
