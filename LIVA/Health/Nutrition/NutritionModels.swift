import Foundation

/// A search-result row from the food database (typeahead list).
struct FoodSearchHit: Codable, Identifiable, Hashable {
    var name: String
    var brand: String?
    var photo: String?
    var kind: String              // "common" | "branded"
    var detailQuery: String?
    var nixItemId: String?
    var calories: Int?

    var id: String { "\(kind)-\(nixItemId ?? detailQuery ?? name)" }
}

/// A fully-resolved food with per-serving macros.
struct FoodItem: Codable, Hashable, Identifiable {
    var id: String { "\(name)-\(brand ?? "")-\(barcode ?? "")-\(calories)" }
    var name: String
    var brand: String?
    var servingLabel: String?
    var servingG: Double?
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatsG: Int
    var fiberG: Double?
    var sugarG: Double?
    var sodiumMg: Double?
    var photo: String?
    var barcode: String?

    enum CodingKeys: String, CodingKey {
        case name, brand, calories, photo, barcode
        case servingLabel = "serving_label"
        case servingG = "serving_g"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
    }
}

/// An AI-estimated meal item (from photo or text), reviewable before logging.
struct AIMealItem: Codable, Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantity: String?
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatsG: Int
    var confidence: Double?

    enum CodingKeys: String, CodingKey {
        case name, quantity, calories, confidence
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
    }
}

/// A favorite food the user saved for one-tap logging.
struct FavoriteFood: Codable, Identifiable, Hashable {
    var id: UUID?
    var name: String
    var brand: String?
    var servingLabel: String?
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatsG: Int

    enum CodingKeys: String, CodingKey {
        case id, name, brand, calories
        case servingLabel = "serving_label"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
    }
}

/// A recently-logged food (from the recent_foods RPC) for quick re-logging.
struct RecentFood: Codable, Identifiable, Hashable {
    var name: String
    var brand: String?
    var servingLabel: String?
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatsG: Int
    var uses: Int

    var id: String { "\(name)-\(brand ?? "")-\(calories)" }

    enum CodingKeys: String, CodingKey {
        case name, brand, calories, uses
        case servingLabel = "serving_label"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatsG = "fats_g"
    }
}
