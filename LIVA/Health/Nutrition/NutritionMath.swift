import Foundation

/// Pure nutrition math — serving/quantity scaling and the diary totals.
/// Unit-tested. The remaining-calorie equation lives in `HealthMath`.
enum NutritionMath {

    struct Scaled: Equatable {
        var calories: Int, protein: Int, carbs: Int, fats: Int
    }

    /// Scale a per-serving food by a quantity multiplier.
    static func scale(_ food: FoodItem, quantity: Double) -> Scaled {
        Scaled(
            calories: Int((Double(food.calories) * quantity).rounded()),
            protein: Int((Double(food.proteinG) * quantity).rounded()),
            carbs: Int((Double(food.carbsG) * quantity).rounded()),
            fats: Int((Double(food.fatsG) * quantity).rounded())
        )
    }

    /// Daily totals across logged entries.
    static func totals(_ entries: [NutritionEntry]) -> HealthMath.MacroTotals {
        HealthMath.totals(entries)
    }
}
