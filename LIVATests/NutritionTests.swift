import Testing
import Foundation
@testable import LIVA

struct NutritionMathTests {
    private func food(cal: Int, p: Int, c: Int, f: Int) -> FoodItem {
        FoodItem(name: "Test", brand: nil, servingLabel: "1 cup", servingG: 100,
                 calories: cal, proteinG: p, carbsG: c, fatsG: f,
                 fiberG: nil, sugarG: nil, sodiumMg: nil, photo: nil, barcode: nil)
    }

    @Test func scaleByQuantityRoundsEach() {
        let s = NutritionMath.scale(food(cal: 100, p: 10, c: 20, f: 5), quantity: 1.5)
        #expect(s.calories == 150)
        #expect(s.protein == 15)
        #expect(s.carbs == 30)
        #expect(s.fats == 8)   // 7.5 rounds to 8
    }

    @Test func scaleByHalf() {
        let s = NutritionMath.scale(food(cal: 200, p: 20, c: 0, f: 9), quantity: 0.5)
        #expect(s.calories == 100)
        #expect(s.protein == 10)
        #expect(s.fats == 5)   // 4.5 rounds to 5
    }

    @Test func diaryTotalsSumEntries() {
        let day = Date()
        let entries = [
            NutritionEntry(customName: "A", meal: .lunch, calories: 500, proteinG: 30, carbsG: 50, fatsG: 15, loggedOn: day),
            NutritionEntry(customName: "B", meal: .dinner, calories: 700, proteinG: 50, carbsG: 60, fatsG: 25, loggedOn: day),
        ]
        let t = NutritionMath.totals(entries)
        #expect(t.calories == 1200)
        #expect(t.protein == 80)
    }

    @Test func remainingEquationWithExercise() {
        // goal 2900 − food 2310 + exercise 620 = 1210
        #expect(HealthMath.remainingCalories(goal: 2900, food: 2310, exercise: 620, countExercise: true) == 1210)
    }
}
