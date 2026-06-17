import Foundation
import Supabase

// MARK: - Edge-function invocation helper

private func invokeData(_ name: String, _ payload: some Encodable & Sendable) async throws -> Data {
    try await LIVA.supabase.functions.invoke(
        name, options: FunctionInvokeOptions(body: payload)
    ) { data, _ in data }
}

// MARK: - Food search (Nutritionix via edge function)

protocol FoodSearchServiceProtocol: Sendable {
    func search(_ query: String) async -> [FoodSearchHit]
    func detail(for hit: FoodSearchHit) async -> FoodItem?
    func barcode(_ code: String) async -> FoodItem?
}

struct FoodSearchService: FoodSearchServiceProtocol {
    struct ListResponse: Decodable { var configured: Bool; var items: [FoodSearchHit]? }
    struct DetailResponse: Decodable { var configured: Bool; var food: FoodItem? }

    struct SearchBody: Encodable, Sendable { let q: String }
    struct DetailQueryBody: Encodable, Sendable { let detailQuery: String }
    struct ItemBody: Encodable, Sendable { let nixItemId: String }
    struct BarcodeBody: Encodable, Sendable { let barcode: String }

    func search(_ query: String) async -> [FoodSearchHit] {
        guard let data = try? await invokeData("food-search", SearchBody(q: query)),
              let r = try? AppJSON.decoder.decode(ListResponse.self, from: data) else { return [] }
        return r.items ?? []
    }

    func detail(for hit: FoodSearchHit) async -> FoodItem? {
        do {
            let data: Data
            if let id = hit.nixItemId {
                data = try await invokeData("food-search", ItemBody(nixItemId: id))
            } else {
                data = try await invokeData("food-search", DetailQueryBody(detailQuery: hit.detailQuery ?? hit.name))
            }
            return try AppJSON.decoder.decode(DetailResponse.self, from: data).food
        } catch { return nil }
    }

    func barcode(_ code: String) async -> FoodItem? {
        guard let data = try? await invokeData("food-search", BarcodeBody(barcode: code)),
              let r = try? AppJSON.decoder.decode(DetailResponse.self, from: data) else { return nil }
        return r.food
    }
}

// MARK: - AI logging (Claude via edge functions)

protocol AINutritionServiceProtocol: Sendable {
    func describe(_ text: String) async -> [AIMealItem]
    func photo(base64: String, mediaType: String) async -> [AIMealItem]
}

struct AINutritionService: AINutritionServiceProtocol {
    struct Response: Decodable { var configured: Bool; var items: [AIMealItem]? }
    struct DescribeBody: Encodable, Sendable { let text: String }
    struct PhotoBody: Encodable, Sendable { let imageBase64: String; let mediaType: String }

    func describe(_ text: String) async -> [AIMealItem] {
        guard let data = try? await invokeData("meal-describe", DescribeBody(text: text)),
              let r = try? AppJSON.decoder.decode(Response.self, from: data) else { return [] }
        return r.items ?? []
    }

    func photo(base64: String, mediaType: String) async -> [AIMealItem] {
        guard let data = try? await invokeData("meal-photo", PhotoBody(imageBase64: base64, mediaType: mediaType)),
              let r = try? AppJSON.decoder.decode(Response.self, from: data) else { return [] }
        return r.items ?? []
    }
}

// MARK: - Nutrition logging (Supabase, offline-aware)

protocol NutritionLogServiceProtocol: Sendable {
    func log(name: String, brand: String?, servingLabel: String?, servingG: Double?,
             quantity: Double, meal: MealType, calories: Int, protein: Int, carbs: Int, fats: Int,
             source: String) async throws
    func quickAdd(calories: Int, meal: MealType) async throws
    func entries(on day: Date) async throws -> [NutritionEntry]
    func delete(_ id: UUID) async throws
    func recents() async -> [RecentFood]
    func favorites() async -> [FavoriteFood]
    func addFavorite(name: String, brand: String?, servingLabel: String?,
                     calories: Int, protein: Int, carbs: Int, fats: Int) async throws
}

struct NutritionLogService: NutritionLogServiceProtocol {
    let writer: RemoteWriter

    func log(name: String, brand: String?, servingLabel: String?, servingG: Double?,
             quantity: Double, meal: MealType, calories: Int, protein: Int, carbs: Int, fats: Int,
             source: String) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable, Sendable {
            let user_id: String; let custom_name: String; let brand: String?
            let meal: String; let quantity: Double; let serving_g: Double?; let serving_label: String?
            let calories: Int; let protein_g: Int; let carbs_g: Int; let fats_g: Int
            let logged_on: String; let source: String
        }
        try await writer.insert("nutrition_logs", Row(
            user_id: uid.uuidString, custom_name: name, brand: brand, meal: meal.rawValue,
            quantity: quantity, serving_g: servingG, serving_label: servingLabel,
            calories: calories, protein_g: protein, carbs_g: carbs, fats_g: fats,
            logged_on: Date().pgDateString, source: source))
    }

    func quickAdd(calories: Int, meal: MealType) async throws {
        try await log(name: "Quick add", brand: nil, servingLabel: nil, servingG: nil,
                      quantity: 1, meal: meal, calories: calories, protein: 0, carbs: 0, fats: 0,
                      source: "quick")
    }

    func entries(on day: Date) async throws -> [NutritionEntry] {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        let data = try await LIVA.supabase.from("nutrition_logs").select()
            .eq("user_id", value: uid.uuidString)
            .eq("logged_on", value: day.pgDateString)
            .order("logged_at", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([NutritionEntry].self, from: data)
    }

    func delete(_ id: UUID) async throws {
        try await LIVA.supabase.from("nutrition_logs").delete().eq("id", value: id.uuidString).execute()
    }

    func recents() async -> [RecentFood] {
        guard let data = try? await LIVA.supabase.rpc("recent_foods", params: ["limit_count": 20]).execute().data
        else { return [] }
        return (try? AppJSON.decoder.decode([RecentFood].self, from: data)) ?? []
    }

    func favorites() async -> [FavoriteFood] {
        guard let uid = LIVA.supabase.currentUserID,
              let data = try? await LIVA.supabase.from("nutrition_favorites").select()
                .eq("user_id", value: uid.uuidString).order("created_at", ascending: false)
                .execute().data
        else { return [] }
        return (try? AppJSON.decoder.decode([FavoriteFood].self, from: data)) ?? []
    }

    func addFavorite(name: String, brand: String?, servingLabel: String?,
                     calories: Int, protein: Int, carbs: Int, fats: Int) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable, Sendable {
            let user_id: String; let name: String; let brand: String?; let serving_label: String?
            let calories: Int; let protein_g: Int; let carbs_g: Int; let fats_g: Int
        }
        try await writer.insert("nutrition_favorites", Row(
            user_id: uid.uuidString, name: name, brand: brand, serving_label: servingLabel,
            calories: calories, protein_g: protein, carbs_g: carbs, fats_g: fats))
    }
}
