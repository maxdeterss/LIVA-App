import Testing
import Foundation
@testable import LIVA

struct HealthMathTests {

    // MARK: Unit conversion

    @Test func poundsToKilograms() {
        #expect(abs(HealthMath.lbToKg(220) - 99.79) < 0.01)
        #expect(abs(HealthMath.kgToLb(100) - 220.46) < 0.01)
    }

    @Test func milesAndMeters() {
        #expect(abs(HealthMath.milesToMeters(1) - 1609.344) < 0.001)
        #expect(abs(HealthMath.metersToMiles(1609.344) - 1) < 0.0001)
    }

    @Test func temperature() {
        #expect(abs(HealthMath.cToF(37) - 98.6) < 0.01)
        #expect(abs(HealthMath.fToC(98.6) - 37) < 0.01)
    }

    // MARK: Pace

    @Test func paceComputesAndFormats() throws {
        // 1 mile in 510s => 8:30 / mi
        let pace = try #require(HealthMath.paceSecPerMile(distanceMeters: 1609.344, seconds: 510))
        #expect(abs(pace - 510) < 0.5)
        #expect(HealthMath.formatPace(secPerMile: pace) == "8:30")
    }

    @Test func paceGuardsAgainstZero() {
        #expect(HealthMath.paceSecPerMile(distanceMeters: 0, seconds: 100) == nil)
        #expect(HealthMath.formatPace(secPerMile: 0) == "--:--")
    }

    // MARK: Macros

    @Test func caloriesFromMacrosUses4_4_9() {
        // 40p / 50c / 10f = 160 + 200 + 90 = 450
        #expect(HealthMath.caloriesFromMacros(protein: 40, carbs: 50, fats: 10) == 450)
    }

    @Test func macroTotalsSum() {
        let entries = [
            NutritionEntry(meal: .breakfast, calories: 400, proteinG: 30, carbsG: 40, fatsG: 12, loggedOn: Date()),
            NutritionEntry(meal: .lunch, calories: 600, proteinG: 45, carbsG: 55, fatsG: 20, loggedOn: Date()),
        ]
        let t = HealthMath.totals(entries)
        #expect(t.calories == 1000)
        #expect(t.protein == 75)
        #expect(t.carbs == 95)
        #expect(t.fats == 32)
    }

    @Test func remainingCaloriesEquation() {
        // goal - food + exercise
        #expect(HealthMath.remainingCalories(goal: 2900, food: 2310, exercise: 620, countExercise: true) == 1210)
        #expect(HealthMath.remainingCalories(goal: 2900, food: 2310, exercise: 620, countExercise: false) == 590)
    }

    // MARK: Progress

    @Test func progressClamps() {
        #expect(HealthMath.progress(50, target: 100) == 0.5)
        #expect(HealthMath.progress(150, target: 100) == 1.0)   // clamps high
        #expect(HealthMath.progress(10, target: 0) == 0.0)      // guards zero target
    }

    // MARK: Stats & latest

    @Test func statsMinAvgMax() throws {
        let s = try #require(HealthMath.stats([10, 20, 30]))
        #expect(s.min == 10)
        #expect(s.max == 30)
        #expect(s.avg == 20)
        #expect(HealthMath.stats([]) == nil)
    }

    @Test func latestPicksMostRecentPerMetric() {
        let old = Date(timeIntervalSince1970: 1000)
        let new = Date(timeIntervalSince1970: 2000)
        let bios = [
            Biometric(recordedAt: old, metric: .hrv, value: 50),
            Biometric(recordedAt: new, metric: .hrv, value: 60),
            Biometric(recordedAt: new, metric: .rhr, value: 55),
        ]
        let latest = HealthMath.latest(bios)
        #expect(latest[.hrv]?.value == 60)   // newer wins
        #expect(latest[.rhr]?.value == 55)
    }
}
