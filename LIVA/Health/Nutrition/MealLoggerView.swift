import SwiftUI
import PhotosUI
import UIKit

/// The fast food-logging hub: search, barcode scan, snap-a-photo AI, describe-AI,
/// quick-add, plus recents and favorites. Reachable in ≤2 taps from HEALTH.
struct MealLoggerView: View {
    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable { case search = "Search", photo = "Photo", describe = "Describe"; var id: String { rawValue } }

    @State private var meal: MealType = MealLoggerView.guessMeal()
    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var results: [FoodSearchHit] = []
    @State private var recents: [RecentFood] = []
    @State private var favorites: [FavoriteFood] = []
    @State private var searching = false

    @State private var photoItem: PhotosPickerItem?
    @State private var describeText = ""
    @State private var aiLoading = false

    @State private var detailFood: FoodItem?
    @State private var aiItems: [AIMealItem]?
    @State private var showBarcode = false
    @State private var showQuickAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                VStack(spacing: 14) {
                    mealPicker
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).padding(.horizontal, Theme.Spacing.screen)

                    switch mode {
                    case .search:   searchTab
                    case .photo:    photoTab
                    case .describe: describeTab
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Log Meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Theme.Palette.ink) }
                ToolbarItem(placement: .primaryAction) { Button("Quick Add") { showQuickAdd = true }.foregroundStyle(Theme.Palette.ink) }
            }
            .sheet(item: $detailFood) { food in
                FoodDetailView(food: food, meal: meal) {}
            }
            .sheet(isPresented: Binding(get: { aiItems != nil }, set: { if !$0 { aiItems = nil } })) {
                AIReviewView(initialItems: aiItems ?? [], meal: meal) {}
            }
            .sheet(isPresented: $showBarcode) {
                BarcodeScannerView { code in Task { await lookupBarcode(code) } }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView(meal: meal) {}
            }
            .task { recents = await env.nutritionLog.recents(); favorites = await env.nutritionLog.favorites() }
        }
    }

    // MARK: Meal type

    private var mealPicker: some View {
        Picker("Meal", selection: $meal) {
            ForEach(MealType.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented).padding(.horizontal, Theme.Spacing.screen)
    }

    // MARK: Search tab

    private var searchTab: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.Palette.inkSecondary)
                    TextField("Search foods", text: $query)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await runSearch() } }
                }.inputFieldStyle()
                Button { showBarcode = true } label: {
                    Image(systemName: "barcode.viewfinder").font(.system(size: 20))
                        .foregroundStyle(Theme.Palette.ink).frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Palette.chip))
                }
            }.padding(.horizontal, Theme.Spacing.screen)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if searching {
                        ProgressView().tint(Theme.Palette.accent).padding(.top, 24)
                    } else if query.isEmpty {
                        quickPicks
                    } else {
                        ForEach(results) { hit in searchRow(hit) }
                    }
                }.padding(.horizontal, Theme.Spacing.screen)
            }
        }
        .onChange(of: query) { _, _ in Task { await runSearch() } }
    }

    @ViewBuilder private func searchRow(_ hit: FoodSearchHit) -> some View {
        Button { Task { await openDetail(hit) } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                    if let brand = hit.brand { Text(brand).font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary) }
                }
                Spacer()
                if let cal = hit.calories { Text("\(cal) cal").font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary) }
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.Palette.inkTertiary)
            }
            .padding(.vertical, 11)
        }.buttonStyle(.plain)
        Divider().overlay(Theme.Palette.divider)
    }

    @ViewBuilder private var quickPicks: some View {
        if !favorites.isEmpty {
            sectionHeader("Favorites")
            ForEach(favorites) { f in
                quickRow(name: f.name, brand: f.brand, calories: f.calories) {
                    Task { try? await env.nutritionLog.log(name: f.name, brand: f.brand, servingLabel: f.servingLabel,
                        servingG: nil, quantity: 1, meal: meal, calories: f.calories, protein: f.proteinG,
                        carbs: f.carbsG, fats: f.fatsG, source: "search") }
                }
            }
        }
        if !recents.isEmpty {
            sectionHeader("Recent")
            ForEach(recents) { r in
                quickRow(name: r.name, brand: r.brand, calories: r.calories) {
                    Task { try? await env.nutritionLog.log(name: r.name, brand: r.brand, servingLabel: r.servingLabel,
                        servingG: nil, quantity: 1, meal: meal, calories: r.calories, protein: r.proteinG,
                        carbs: r.carbsG, fats: r.fatsG, source: "search") }
                }
            }
        }
        if favorites.isEmpty && recents.isEmpty {
            Text("Search a food, scan a barcode, or snap a photo to get started.")
                .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center).padding(.top, 30).padding(.horizontal, 20)
        }
    }

    private func quickRow(name: String, brand: String?, calories: Int, add: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Palette.ink).lineLimit(1)
                if let brand { Text(brand).font(.system(size: 12)).foregroundStyle(Theme.Palette.inkSecondary) }
            }
            Spacer()
            Text("\(calories) cal").font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
            Button(action: add) {
                Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.Palette.ink)
            }
        }.padding(.vertical, 9)
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack { SectionLabel(text); Spacer() }.padding(.top, 14).padding(.bottom, 4)
    }

    // MARK: Photo tab

    private var photoTab: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 40))
                    Text("Snap or choose a meal photo").font(.system(size: 15, weight: .medium))
                    Text("AI estimates calories & macros").font(.system(size: 12)).foregroundStyle(Theme.Palette.inkTertiary)
                }
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Palette.surface))
            }
            if aiLoading { ProgressView("Analyzing…").tint(Theme.Palette.accent) }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .onChange(of: photoItem) { _, _ in Task { await analyzePhoto() } }
    }

    // MARK: Describe tab

    private var describeTab: some View {
        VStack(spacing: 14) {
            Text("Describe what you ate")
                .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("two eggs, toast with butter, black coffee", text: $describeText, axis: .vertical)
                .lineLimit(2...5).inputFieldStyle()
            Button {
                Task { await analyzeDescribe() }
            } label: {
                HStack { if aiLoading { ProgressView().tint(Theme.Palette.tabBarText) }; Text("Estimate with AI") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(describeText.trimmingCharacters(in: .whitespaces).isEmpty || aiLoading)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screen)
    }

    // MARK: Actions

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; return }
        searching = true
        results = await env.foodSearch.search(q)
        searching = false
    }

    private func openDetail(_ hit: FoodSearchHit) async {
        if let food = await env.foodSearch.detail(for: hit) { detailFood = food }
    }

    private func lookupBarcode(_ code: String) async {
        if let food = await env.foodSearch.barcode(code) { detailFood = food }
    }

    private func analyzePhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        aiLoading = true
        let resized = image.resized(maxDimension: 1024)
        let jpeg = resized.jpegData(compressionQuality: 0.7) ?? data
        let items = await env.ai.photo(base64: jpeg.base64EncodedString(), mediaType: "image/jpeg")
        aiLoading = false
        aiItems = items
    }

    private func analyzeDescribe() async {
        aiLoading = true
        let items = await env.ai.describe(describeText)
        aiLoading = false
        aiItems = items
    }

    static func guessMeal() -> MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }
}

// MARK: - Quick add

struct QuickAddView: View {
    let meal: MealType
    var onLogged: () -> Void
    @Environment(HealthEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var calories = ""
    @State private var saving = false

    var body: some View {
        LogSheet(title: "Quick Add", canSave: parseInt(calories) != nil, isSaving: saving) {
            guard let c = parseInt(calories) else { return }
            saving = true
            Task { try? await env.nutritionLog.quickAdd(calories: c, meal: meal); saving = false; onLogged(); dismiss() }
        } content: {
            Text("Log calories without the details — refine later.")
                .font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
            NumberField(label: "Calories", text: $calories, unit: "cal")
        }
    }
}

// MARK: - Image resize helper

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
