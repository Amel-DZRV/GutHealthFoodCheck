import SwiftData
import SwiftUI

/// One meal of one day: ingredients, notes, instructions and the eaten toggle.
/// Editing swaps the day's template for a copy, so the displayed key is tracked in state.
struct MealDetailView: View {
    let mealKey: String
    let person: String
    let date: Date
    var testAddition: String? = nil

    @Environment(\.modelContext) private var context
    @Query private var allMeals: [MealDefinition]
    @Query private var allCompletions: [MealCompletion]

    @State private var currentKey: String
    @State private var showEdit = false
    /// The copy just made by `editableMeal`; covers the moment before `@Query` sees it.
    @State private var editingMeal: MealDefinition?

    init(mealKey: String, person: String, date: Date, testAddition: String? = nil) {
        self.mealKey = mealKey
        self.person = person
        self.date = date
        self.testAddition = testAddition
        _currentKey = State(initialValue: mealKey)
    }

    private var day: Date { Calendar.current.startOfDay(for: date) }

    private var meal: MealDefinition? {
        allMeals.first { $0.key == currentKey }
            ?? (editingMeal?.key == currentKey ? editingMeal : nil)
    }

    private var completion: MealCompletion? {
        allCompletions.first {
            $0.person == person && $0.mealKey == currentKey
                && Calendar.current.startOfDay(for: $0.date) == day
        }
    }

    var body: some View {
        Group {
            if let meal {
                content(meal)
            } else {
                ContentUnavailableView("Meal not found", systemImage: "fork.knife")
            }
        }
        .navigationTitle(meal.map { MealSlot.title($0.slot) } ?? "Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if meal != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", action: startEditing)
                }
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            if let target = editingMeal ?? meal {
                MealEditView(meal: target)
            }
        }
    }

    private func content(_ meal: MealDefinition) -> some View {
        List {
            Section {
                header(meal)
            }

            Section("Ingredients") {
                if let testAddition, !testAddition.isEmpty {
                    Label(testAddition, systemImage: "plus.circle.fill")
                        .font(.body.bold())
                        .foregroundStyle(.blue)
                }
                ForEach(meal.sortedItems) { item in
                    ingredientRow(item)
                }
            }

            if !meal.notes.isEmpty {
                Section("Notes") {
                    Text(meal.notes)
                }
            }

            Section {
                NavigationLink {
                    StepsView(meal: meal)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Instructions")
                        Text(stepsSubtitle(meal))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle("Eaten", isOn: eatenBinding)
            }
        }
    }

    private func header(_ meal: MealDefinition) -> some View {
        let macros = meal.macros
        return VStack(alignment: .leading, spacing: 6) {
            Text(meal.name)
                .font(.title2.bold())
            Text("\(macros.kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                .font(.headline)
            HStack(spacing: 14) {
                macroLabel("P", macros.protein)
                macroLabel("C", macros.carbs)
                macroLabel("F", macros.fat)
                macroLabel("Fibre", macros.fibre)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func macroLabel(_ name: String, _ grams: Double) -> some View {
        Text("\(name) \(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
    }

    private func ingredientRow(_ item: MealItem) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                if !item.state.isEmpty {
                    Text(item.state)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(QuantityFormat.string(item.quantity, unit: item.unit))
                Text("\(item.macros.kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepsSubtitle(_ meal: MealDefinition) -> String {
        let count = meal.steps.count
        if count == 0 { return "No steps yet" }
        return count == 1 ? "1 step" : "\(count) steps"
    }

    private var eatenBinding: Binding<Bool> {
        Binding(
            get: { completion != nil },
            set: { eaten in
                if eaten {
                    guard completion == nil else { return }
                    context.insert(MealCompletion(person: person, date: day, mealKey: currentKey))
                } else if let completion {
                    context.delete(completion)
                }
                try? context.save()
            }
        )
    }

    /// Swaps the day's template for an editable copy, then opens the editor on it.
    private func startEditing() {
        let editable = MealEditing.editableMeal(key: currentKey, person: person, date: day, context: context)
        currentKey = editable.key
        editingMeal = editable
        showEdit = true
    }
}
