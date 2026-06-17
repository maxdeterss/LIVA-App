import SwiftUI

/// Adjust serving quantity for a resolved food, then log it.
struct FoodDetailView: View {
    let food: FoodItem
    let meal: MealType
    var onLogged: () -> Void

    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Double = 1
    @State private var saving = false

    private var scaled: NutritionMath.Scaled { NutritionMath.scale(food, quantity: quantity) }

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        LivaCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionLabel("Servings")
                                Stepper(value: $quantity, in: 0.25...20, step: 0.25) {
                                    Text(String(format: "%.2f × %@", quantity, food.servingLabel ?? "serving"))
                                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Palette.ink)
                                }
                            }
                        }
                        LivaCard {
                            HStack(spacing: 18) {
                                macro("\(scaled.calories)", "CAL")
                                macro("\(scaled.protein)g", "PROTEIN")
                                macro("\(scaled.carbs)g", "CARBS")
                                macro("\(scaled.fats)g", "FATS")
                            }
                        }
                        Button {
                            Task {
                                try? await env.nutritionLog.addFavorite(
                                    name: food.name, brand: food.brand, servingLabel: food.servingLabel,
                                    calories: food.calories, protein: food.proteinG, carbs: food.carbsG, fats: food.fatsG)
                            }
                        } label: { Label("Save to favorites", systemImage: "star") }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(Theme.Spacing.screen).padding(.bottom, 90)
                }
                VStack {
                    Spacer()
                    Button { log() } label: {
                        HStack { if saving { ProgressView().tint(Theme.Palette.tabBarText) }
                            Text("Add to \(meal.title)") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(Theme.Spacing.screen).background(Theme.Palette.background.opacity(0.95))
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(food.name).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.Palette.ink)
            if let brand = food.brand { Text(brand).font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary) }
        }
    }

    private func macro(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.Palette.inkSecondary)
        }.frame(maxWidth: .infinity)
    }

    private func log() {
        saving = true
        let s = scaled
        Task {
            try? await env.nutritionLog.log(
                name: food.name, brand: food.brand, servingLabel: food.servingLabel, servingG: food.servingG,
                quantity: quantity, meal: meal, calories: s.calories, protein: s.protein,
                carbs: s.carbs, fats: s.fats, source: food.barcode != nil ? "barcode" : "search")
            saving = false; onLogged(); dismiss()
        }
    }
}

/// Review AI-detected meal items, drop any that are wrong, then log the rest.
struct AIReviewView: View {
    let initialItems: [AIMealItem]
    let meal: MealType
    var onLogged: () -> Void

    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var items: [AIMealItem] = []
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Review & adjust").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.Palette.ink)
                        Text("AI estimates — remove anything that's off, then log.")
                            .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                        if items.isEmpty {
                            EmptyStateView(systemName: "sparkles", title: "No items detected",
                                           message: "Try a clearer photo, or describe the meal in words.")
                        }
                        ForEach(items) { item in itemRow(item) }
                    }
                    .padding(Theme.Spacing.screen).padding(.bottom, 90)
                }
                if !items.isEmpty {
                    VStack { Spacer()
                        Button { logAll() } label: {
                            HStack { if saving { ProgressView().tint(Theme.Palette.tabBarText) }
                                Text("Log \(items.count) item\(items.count == 1 ? "" : "s")") }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(Theme.Spacing.screen).background(Theme.Palette.background.opacity(0.95))
                    }
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
            .onAppear { if items.isEmpty { items = initialItems } }
        }
    }

    private func itemRow(_ item: AIMealItem) -> some View {
        LivaCard(padding: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.Palette.ink)
                    if let q = item.quantity { Text(q).font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary) }
                    Text("\(item.calories) cal · P\(item.proteinG) C\(item.carbsG) F\(item.fatsG)")
                        .font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
                if let c = item.confidence {
                    Text("\(Int(c * 100))%").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
                Button { items.removeAll { $0.id == item.id } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Palette.inkTertiary)
                }
            }
        }
    }

    private func logAll() {
        saving = true
        let toLog = items
        Task {
            for item in toLog {
                try? await env.nutritionLog.log(
                    name: item.name, brand: nil, servingLabel: item.quantity, servingG: nil,
                    quantity: 1, meal: meal, calories: item.calories, protein: item.proteinG,
                    carbs: item.carbsG, fats: item.fatsG, source: "ai")
            }
            saving = false; onLogged(); dismiss()
        }
    }
}
