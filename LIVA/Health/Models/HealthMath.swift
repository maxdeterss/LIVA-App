import Foundation

/// Pure functions for all health/tracking math. No I/O, fully unit-testable.
enum HealthMath {

    // MARK: Unit conversion

    static let kgPerLb = 0.45359237
    static func lbToKg(_ lb: Double) -> Double { lb * kgPerLb }
    static func kgToLb(_ kg: Double) -> Double { kg / kgPerLb }

    static let kmPerMile = 1.609344
    static func milesToMeters(_ mi: Double) -> Double { mi * kmPerMile * 1000 }
    static func metersToMiles(_ m: Double) -> Double { m / 1000 / kmPerMile }

    static func cToF(_ c: Double) -> Double { c * 9 / 5 + 32 }
    static func fToC(_ f: Double) -> Double { (f - 32) * 5 / 9 }

    // MARK: Pace & speed

    /// Pace in seconds per mile from distance (meters) and moving time (seconds).
    static func paceSecPerMile(distanceMeters: Double, seconds: Double) -> Double? {
        guard distanceMeters > 0, seconds > 0 else { return nil }
        return seconds / metersToMiles(distanceMeters)
    }

    /// Formats a pace (sec/mi) as "m:ss".
    static func formatPace(secPerMile: Double) -> String {
        guard secPerMile.isFinite, secPerMile > 0 else { return "--:--" }
        let total = Int(secPerMile.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Macros

    /// Calories implied by macro grams (4/4/9).
    static func caloriesFromMacros(protein: Int, carbs: Int, fats: Int) -> Int {
        protein * 4 + carbs * 4 + fats * 9
    }

    struct MacroTotals: Equatable {
        var calories = 0, protein = 0, carbs = 0, fats = 0
    }

    static func totals(_ entries: [NutritionEntry]) -> MacroTotals {
        entries.reduce(into: MacroTotals()) { acc, e in
            acc.calories += e.calories
            acc.protein += e.proteinG
            acc.carbs += e.carbsG
            acc.fats += e.fatsG
        }
    }

    /// MyFitnessPal-style: remaining = goal − food + exercise.
    static func remainingCalories(goal: Int, food: Int, exercise: Int, countExercise: Bool) -> Int {
        goal - food + (countExercise ? exercise : 0)
    }

    // MARK: Progress

    /// Clamped 0...1 ratio for rings/bars.
    static func progress(_ value: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(value) / Double(target), 0), 1)
    }

    // MARK: Aggregates over a stream of biometrics

    struct Stats: Equatable { var min: Double; var max: Double; var avg: Double }

    static func stats(_ values: [Double]) -> Stats? {
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return Stats(min: values.min()!, max: values.max()!, avg: sum / Double(values.count))
    }

    /// Latest value per metric from a stream (most recent recordedAt wins).
    static func latest(_ biometrics: [Biometric]) -> [BiometricKind: Biometric] {
        var out: [BiometricKind: Biometric] = [:]
        for b in biometrics.sorted(by: { $0.recordedAt < $1.recordedAt }) {
            out[b.metric] = b
        }
        return out
    }
}
