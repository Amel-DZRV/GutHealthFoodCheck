import SwiftData
import SwiftUI

/// Nina's home screen: the day's meals, eaten toggles and a calorie summary.
struct NinaHomeView: View {
    private static let person = Profile.nina.rawValue

    @Environment(\.modelContext) private var context
    @Query private var allEntries: [PlanEntry]
    @Query private var allOverrides: [DayOverride]
    @Query private var allMeals: [MealDefinition]
    @Query private var allCompletions: [MealCompletion]
    @Query private var allTargets: [PersonTargets]
    @Query private var settingsList: [MealPlanSettings]

    @State private var date = Calendar.current.startOfDay(for: .now)
    @State private var showingImport = false
    @State private var showingShopping = false
    @State private var showingSettings = false

    private var settings: MealPlanSettings? { settingsList.first }

    private var isImported: Bool { settings?.importedAt != nil }

    var body: some View {
        NavigationStack {
            Group {
                if isImported {
                    dayList
                } else {
                    ContentUnavailableView {
                        Label("Import your meal plan", systemImage: "tray.and.arrow.down")
                    } description: {
                        Text("Import the meal plan file to see your meals here.")
                    } actions: {
                        Button("Import") { showingImport = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Meals")
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                date = Calendar.current.startOfDay(for: .now)
            }
            .navigationDestination(for: String.self) { key in
                MealDetailView(mealKey: key, person: Self.person, date: date)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isImported {
                        Button {
                            showingShopping = true
                        } label: {
                            Image(systemName: "cart")
                        }
                        .accessibilityLabel("Shopping list")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingImport) {
                ImportPlanView()
            }
            .sheet(isPresented: $showingShopping) {
                ShoppingListView(profile: .nina)
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    MealPlanSettingsView(profile: .nina)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingSettings = false }
                            }
                        }
                }
            }
        }
    }

    private var dayList: some View {
        let day = computeDay()
        return List {
            Section {
                DayHeaderView(date: $date, training: "")
                DaySummaryCard(summary: day.summary)
            }
            Section("Meals") {
                if day.meals.isEmpty {
                    Text("No meals planned for this day")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(day.meals, id: \.key) { meal in
                        NavigationLink(value: meal.key) {
                            MealRowView(
                                title: MealSlot.title(meal.slot),
                                name: meal.name,
                                summary: meal.itemSummary,
                                kcal: meal.macros.kcal,
                                isEaten: day.eatenKeys.contains(meal.key),
                                onToggle: { toggle(meal.key) }
                            )
                        }
                    }
                }
            }
        }
    }

    /// Resolves Nina's meals for `date`, which of them are eaten, and the summary card values.
    private func computeDay() -> (meals: [MealDefinition], eatenKeys: Set<String>, summary: DaySummary) {
        let day = Calendar.current.startOfDay(for: date)
        let resolved = MealResolver.resolve(
            person: Self.person,
            date: day,
            rotationStart: settings?.rotationStart ?? day,
            entries: allEntries.filter { $0.person == Self.person }.map(\.snapshot),
            overrides: allOverrides.filter { $0.person == Self.person }.map(\.snapshot)
        )
        let meals = resolved.mealKeys.compactMap { key in allMeals.first { $0.key == key } }
        let eatenKeys = Set(
            allCompletions
                .filter { $0.person == Self.person && $0.date == day }
                .map(\.mealKey)
        )
        let target = allTargets.first { $0.person == Self.person }?.snapshot
            ?? TargetsSnapshot(kcal: 2000, proteinMin: 130, proteinMax: 150, carbs: nil, fat: nil, fibre: nil)
        let summary = DaySummaryBuilder.build(
            meals: meals.map { ($0.key, $0.macros) },
            eatenKeys: eatenKeys,
            target: target
        )
        return (meals, eatenKeys, summary)
    }

    /// Inserts or deletes the completion for this meal on the selected day.
    private func toggle(_ key: String) {
        let day = Calendar.current.startOfDay(for: date)
        let existing = allCompletions.filter {
            $0.person == Self.person && $0.date == day && $0.mealKey == key
        }
        if existing.isEmpty {
            context.insert(MealCompletion(person: Self.person, date: day, mealKey: key))
        } else {
            for completion in existing {
                context.delete(completion)
            }
        }
        try? context.save()
    }
}

#Preview {
    NinaHomeView()
        .modelContainer(for: [
            PlanEntry.self, DayOverride.self, MealDefinition.self, MealCompletion.self,
            PersonTargets.self, MealPlanSettings.self, MealItem.self, MealStep.self,
            CatalogIngredient.self, ShoppingListItem.self,
        ], inMemory: true)
}
