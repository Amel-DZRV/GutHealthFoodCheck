import SwiftData
import SwiftUI

/// Adds a new food, or edits an existing one when `food` is passed.
/// Blocks saving when another item already has the same name and portion.
struct FoodFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allFoods: [FoodItem]

    private let food: FoodItem?

    @State private var name: String
    @State private var portion: Double?
    @State private var unit: PortionUnit
    @State private var category: FODMAPCategory
    @State private var notes: String
    @State private var logReactionNow = false
    @State private var draft = SymptomDraft()

    init(food: FoodItem? = nil) {
        self.food = food
        _name = State(initialValue: food?.name ?? "")
        _portion = State(initialValue: food?.portion)
        _unit = State(initialValue: food?.unit ?? .grams)
        _category = State(initialValue: food?.category ?? .mixed)
        _notes = State(initialValue: food?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name, e.g. Banana", text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        TextField("Portion", value: $portion, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $unit) {
                            ForEach(PortionUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                    Picker("FODMAP group", selection: $category) {
                        ForEach(FODMAPCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }
                }

                if let duplicate {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Already tracked")
                                    .font(.headline)
                                Text("\(duplicate.name) · \(duplicate.portionLabel) in \(duplicate.category.title)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        if food == nil {
                            NavigationLink("Log a reaction to it instead") {
                                LogEntryView(food: duplicate) { dismiss() }
                            }
                        }
                    }
                } else if !otherPortions.isEmpty {
                    Section {
                        Text("Also tracked at: \(otherPortions.map(\.portionLabel).joined(separator: ", "))")
                    } footer: {
                        Text("Different portions are tracked separately. FODMAP tolerance often depends on the amount.")
                    }
                }

                Section("Notes") {
                    TextField("Brand, preparation, ripeness…", text: $notes, axis: .vertical)
                }

                if food == nil {
                    Section {
                        Toggle("Log a reaction now", isOn: $logReactionNow.animation())
                    }
                    if logReactionNow {
                        SymptomFields(draft: $draft)
                    }
                }
            }
            .navigationTitle(food == nil ? "Add Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An existing item (other than the one being edited) with the same name and portion.
    private var duplicate: FoodItem? {
        guard let portion, !trimmedName.isEmpty else { return nil }
        return allFoods.first { $0 !== food && $0.isSameFood(name: trimmedName, portion: portion, unit: unit) }
    }

    /// Same food name tracked at other portions.
    private var otherPortions: [FoodItem] {
        guard !trimmedName.isEmpty else { return [] }
        return allFoods
            .filter { $0 !== food && $0.hasSameName(as: trimmedName) }
            .sorted { $0.portion < $1.portion }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && (portion ?? 0) > 0 && duplicate == nil
    }

    private func save() {
        guard canSave, let portion else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let food {
            food.name = trimmedName
            food.portion = portion
            food.unit = unit
            food.category = category
            food.notes = trimmedNotes
        } else {
            let item = FoodItem(name: trimmedName, portion: portion, unit: unit, category: category, notes: trimmedNotes)
            context.insert(item)
            if logReactionNow {
                let log = draft.makeLog()
                context.insert(log)
                log.food = item
            }
        }
        dismiss()
    }
}

#Preview {
    FoodFormView()
        .modelContainer(for: [FoodItem.self, SymptomLog.self], inMemory: true)
}
