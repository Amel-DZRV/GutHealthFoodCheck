import SwiftData
import SwiftUI

/// Meal plan settings for one profile. Pushed inside the caller's NavigationStack.
struct MealPlanSettingsView: View {
    let profile: Profile

    @Environment(\.modelContext) private var context
    @AppStorage(Profile.storageKey) private var profileRaw = ""
    @Query private var allTargets: [PersonTargets]
    @Query private var settingsList: [MealPlanSettings]
    @Query(sort: \MealDefinition.name) private var allMeals: [MealDefinition]
    @Query(sort: \CatalogIngredient.name) private var ingredients: [CatalogIngredient]

    @State private var showingImport = false
    @State private var confirmingSwitch = false

    private var targets: PersonTargets? {
        allTargets.first { $0.person == profile.rawValue }
    }

    private var templates: [MealDefinition] {
        allMeals
            .filter { $0.isTemplate && $0.person == profile.rawValue }
            .sorted { lhs, rhs in
                let l = MealSlot.all.firstIndex(of: lhs.slot) ?? MealSlot.all.count
                let r = MealSlot.all.firstIndex(of: rhs.slot) ?? MealSlot.all.count
                if l != r { return l < r }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        Form {
            targetsSection
            planSection
            templatesSection
            staplesSection
            switchSection
        }
        .navigationTitle("Meal plan settings")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
        .sheet(isPresented: $showingImport) {
            ImportPlanView()
        }
        .alert("Switch profile?", isPresented: $confirmingSwitch) {
            Button("Switch profile", role: .destructive) {
                try? context.save()
                profileRaw = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be asked who is using this phone. No data is deleted.")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var targetsSection: some View {
        if let targets {
            TargetFields(targets: targets)
        } else {
            Section("Daily targets") {
                Text("Import a plan to set targets")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var planSection: some View {
        Section("Plan") {
            Button("Import plan") { showingImport = true }
            if let settings = settingsList.first {
                PlanFields(settings: settings, showsRotation: profile == .nina)
            } else {
                LabeledContent("Imported", value: "Never")
            }
        }
    }

    private var templatesSection: some View {
        Section {
            if templates.isEmpty {
                Text("No meals yet")
                    .foregroundStyle(.secondary)
            }
            ForEach(templates) { meal in
                NavigationLink {
                    MealEditView(meal: meal)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                        Text(MealSlot.title(meal.slot))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Meal templates")
        } footer: {
            Text("Editing a template changes every day that uses it, except days you've edited separately.")
        }
    }

    private var staplesSection: some View {
        Section {
            if ingredients.isEmpty {
                Text("No ingredients yet")
                    .foregroundStyle(.secondary)
            }
            ForEach(ingredients) { ingredient in
                StapleRow(ingredient: ingredient)
            }
        } header: {
            Text("Shopping staples")
        } footer: {
            Text("Staples are left out of shopping lists.")
        }
    }

    private var switchSection: some View {
        Section {
            Button("Switch profile", role: .destructive) {
                confirmingSwitch = true
            }
        }
    }
}

// MARK: - Targets

private struct TargetFields: View {
    @Bindable var targets: PersonTargets

    var body: some View {
        Section("Daily targets") {
            NumberRow(title: "Calories", unit: "kcal", value: $targets.kcal)
            NumberRow(title: "Protein min", unit: "g", value: $targets.proteinMin)
            OptionalNumberRow(title: "Protein max", unit: "g", value: $targets.proteinMax)
            OptionalNumberRow(title: "Carbs", unit: "g", value: $targets.carbs)
            OptionalNumberRow(title: "Fat", unit: "g", value: $targets.fat)
            OptionalNumberRow(title: "Fibre", unit: "g", value: $targets.fibre)
        }
    }
}

private struct NumberRow: View {
    let title: String
    let unit: String
    @Binding var value: Double

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A target that can be switched off ("Set target"), which stores nil.
private struct OptionalNumberRow: View {
    let title: String
    let unit: String
    @Binding var value: Double?

    var body: some View {
        Toggle("Set \(title.lowercased()) target", isOn: enabled)
        if value != nil {
            NumberRow(title: title, unit: unit, value: number)
        }
    }

    private var enabled: Binding<Bool> {
        Binding {
            value != nil
        } set: { on in
            value = on ? (value ?? 0) : nil
        }
    }

    private var number: Binding<Double> {
        Binding {
            value ?? 0
        } set: { newValue in
            value = newValue
        }
    }
}

// MARK: - Plan

private struct PlanFields: View {
    @Bindable var settings: MealPlanSettings
    let showsRotation: Bool

    var body: some View {
        if let importedAt = settings.importedAt {
            LabeledContent("Imported", value: importedAt.formatted(date: .abbreviated, time: .omitted))
        } else {
            LabeledContent("Imported", value: "Never")
        }
        if showsRotation {
            DatePicker("Rotation week 1 starts", selection: rotationStart, displayedComponents: .date)
        }
    }

    /// Snaps the chosen date to the Sunday on or before it.
    private var rotationStart: Binding<Date> {
        Binding {
            settings.rotationStart
        } set: { picked in
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: picked)
            let weekday = calendar.component(.weekday, from: day)   // 1 = Sunday
            settings.rotationStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: day) ?? day
        }
    }
}

// MARK: - Staples

private struct StapleRow: View {
    @Bindable var ingredient: CatalogIngredient

    var body: some View {
        Toggle(ingredient.name, isOn: $ingredient.isStaple)
    }
}
