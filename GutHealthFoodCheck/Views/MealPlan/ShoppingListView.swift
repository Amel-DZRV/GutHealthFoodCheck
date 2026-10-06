import SwiftUI
import SwiftData

/// Shopping list: generate it from the plan, then check off, edit, add and delete lines freely.
struct ShoppingListView: View {
    let profile: Profile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ShoppingListItem.order) private var items: [ShoppingListItem]
    @Query private var settingsList: [MealPlanSettings]
    @Query private var planEntries: [PlanEntry]
    @Query private var overrides: [DayOverride]
    @Query private var meals: [MealDefinition]
    @Query private var ingredients: [CatalogIngredient]

    @State private var start = Calendar.current.startOfDay(for: .now)
    @State private var days = 7
    @State private var household = true
    @State private var didLoadSettings = false
    @State private var confirmReplace = false
    @State private var editor: ShoppingEditorTarget?

    private var settings: MealPlanSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                generateSection
                if items.isEmpty {
                    Section {
                        Text("No items yet. Generate a list from the meal plan, or add items with +.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(groups) { group in
                        Section(ShoppingAisle.title(group.aisle)) {
                            ForEach(group.items) { item in
                                ShoppingRow(
                                    item: item,
                                    onToggle: { toggle(item) },
                                    onEdit: { editor = ShoppingEditorTarget(item: item) }
                                )
                                .swipeActions {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("Reset checks") { resetChecks() }
                            .disabled(!items.contains { $0.isChecked })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                    Button {
                        editor = ShoppingEditorTarget(item: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                }
            }
            .sheet(item: $editor) { target in
                ShoppingItemEditor(item: target.item, nextOrder: (items.map(\.order).max() ?? -1) + 1)
            }
            .confirmationDialog(
                "Replace generated items? Items you added yourself are kept.",
                isPresented: $confirmReplace,
                titleVisibility: .visible
            ) {
                Button("Replace", role: .destructive) { generate() }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear(perform: loadSettings)
        }
    }

    // MARK: Generate section

    private var generateSection: some View {
        Section("Generate") {
            DatePicker("Start", selection: $start, displayedComponents: .date)
            Stepper("\(days) days", value: $days, in: 1...28)
            HStack {
                Text("Quick pick")
                Spacer()
                Button("7 days") { days = 7 }
                    .buttonStyle(.borderless)
                Button("14 days") { days = 14 }
                    .buttonStyle(.borderless)
                    .padding(.leading, 12)
            }
            Toggle(isOn: $household) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(household ? "Household" : "Me only")
                    Text(household ? "Amel and Nina" : profile.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Generate list") {
                if items.contains(where: { !$0.isManual }) {
                    confirmReplace = true
                } else {
                    generate()
                }
            }
        }
    }

    // MARK: List data

    private var groups: [ShoppingAisleGroup] {
        let byAisle = Dictionary(grouping: items, by: \.aisle)
        return byAisle.keys
            .sorted { a, b in
                let ra = ShoppingAisle.rank(a), rb = ShoppingAisle.rank(b)
                return ra != rb ? ra < rb : a < b
            }
            .map { aisle in
                let sorted = (byAisle[aisle] ?? []).sorted { a, b in
                    if a.isChecked != b.isChecked { return !a.isChecked }
                    return a.order < b.order
                }
                return ShoppingAisleGroup(aisle: aisle, items: sorted)
            }
    }

    // MARK: Actions

    /// Takes the saved shopping range from the settings record once, when it exists.
    private func loadSettings() {
        guard !didLoadSettings else { return }
        didLoadSettings = true
        guard let settings else { return }
        start = Calendar.current.startOfDay(for: settings.shoppingStart)
        days = min(max(settings.shoppingDays, 1), 28)
        household = settings.shoppingHousehold
    }

    private func generate() {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let people = household ? Profile.allCases.map(\.rawValue) : [profile.rawValue]

        let inputs = ShoppingInputBuilder.items(
            start: startDay,
            days: days,
            people: people,
            rotationStart: settings?.rotationStart ?? startDay,
            entries: planEntries.map(\.snapshot),
            overrides: overrides.map(\.snapshot),
            meals: meals
        )
        let lines = ShoppingGenerator.generate(items: inputs, catalog: ShoppingInputBuilder.catalog(ingredients))

        for item in items where !item.isManual {
            context.delete(item)
        }
        for (index, line) in lines.enumerated() {
            context.insert(ShoppingListItem(
                name: line.name,
                quantity: line.quantity,
                unit: line.unit,
                aisle: line.aisle,
                order: index,
                isChecked: false,
                isManual: false,
                sourceKey: line.key
            ))
        }
        if let settings {
            settings.shoppingStart = startDay
            settings.shoppingDays = days
            settings.shoppingHousehold = household
        }
        try? context.save()
    }

    private func toggle(_ item: ShoppingListItem) {
        item.isChecked.toggle()
        try? context.save()
    }

    private func delete(_ item: ShoppingListItem) {
        context.delete(item)
        try? context.save()
    }

    private func resetChecks() {
        for item in items where item.isChecked {
            item.isChecked = false
        }
        try? context.save()
    }
}

/// The lines of one aisle, in display order.
private struct ShoppingAisleGroup: Identifiable {
    let aisle: String
    let items: [ShoppingListItem]
    var id: String { aisle }
}

// MARK: - Input building

/// Turns the plan into the plain inputs `ShoppingGenerator` works on.
private enum ShoppingInputBuilder {
    /// Every item of every resolved meal, for each day in the range and each person, at its current quantity.
    static func items(start: Date, days: Int, people: [String], rotationStart: Date,
                      entries: [PlanEntrySnapshot], overrides: [DayOverrideSnapshot],
                      meals: [MealDefinition]) -> [ShoppingInputItem] {
        let calendar = Calendar.current
        var result: [ShoppingInputItem] = []
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            for person in people {
                let resolved = MealResolver.resolve(
                    person: person, date: date, rotationStart: rotationStart,
                    entries: entries, overrides: overrides
                )
                for key in resolved.mealKeys {
                    guard let meal = meals.first(where: { $0.key == key }) else { continue }
                    for item in meal.sortedItems {
                        result.append(ShoppingInputItem(
                            ingredientKey: item.ingredientKey,
                            quantity: item.quantity,
                            unit: item.unit,
                            state: item.state
                        ))
                    }
                }
            }
        }
        return result
    }

    static func catalog(_ ingredients: [CatalogIngredient]) -> [String: CatalogSnapshot] {
        var map: [String: CatalogSnapshot] = [:]
        for ingredient in ingredients {
            map[ingredient.key] = CatalogSnapshot(
                name: ingredient.name,
                unit: ingredient.unit,
                aisle: ingredient.aisle,
                cookedToDryRatio: ingredient.cookedToDryRatio,
                isStaple: ingredient.isStaple,
                expansion: ingredient.expansion
            )
        }
        return map
    }
}

// MARK: - Row

private struct ShoppingRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.name)" : "Check \(item.name)")

            HStack {
                Text(item.name)
                    .strikethrough(item.isChecked)
                Spacer()
                Text(QuantityFormat.string(item.quantity, unit: item.unit))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(item.isChecked ? Color.secondary : Color.primary)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Editor

/// Identifies what the edit sheet shows: an existing line, or a new manual one (`item == nil`).
private struct ShoppingEditorTarget: Identifiable {
    let id = UUID()
    let item: ShoppingListItem?
}

/// Edit sheet for one shopping line; also used to add a manual line.
private struct ShoppingItemEditor: View {
    let item: ShoppingListItem?
    let nextOrder: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: Double
    @State private var unit: String
    @State private var aisle: String

    init(item: ShoppingListItem?, nextOrder: Int) {
        self.item = item
        self.nextOrder = nextOrder
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _unit = State(initialValue: item?.unit ?? "pcs")
        _aisle = State(initialValue: item?.aisle ?? "other")
    }

    private var units: [String] {
        var list = ["g", "ml", "pcs", ""]
        if !list.contains(unit) { list.append(unit) }
        return list
    }

    private var aisles: [String] {
        var list = ShoppingAisle.order + ["other"]
        if !list.contains(aisle) { list.append(aisle) }
        return list
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Quantity", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Unit", selection: $unit) {
                    ForEach(units, id: \.self) { Text($0.isEmpty ? "None" : $0).tag($0) }
                }
                Picker("Aisle", selection: $aisle) {
                    ForEach(aisles, id: \.self) { Text(ShoppingAisle.title($0)).tag($0) }
                }
            }
            .navigationTitle(item == nil ? "Add item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let item {
            item.name = trimmed
            item.quantity = quantity
            item.unit = unit
            item.aisle = aisle
        } else {
            context.insert(ShoppingListItem(
                name: trimmed,
                quantity: quantity,
                unit: unit,
                aisle: aisle,
                order: nextOrder,
                isChecked: false,
                isManual: true,
                sourceKey: ""
            ))
        }
        try? context.save()
        dismiss()
    }
}
