import SwiftData
import SwiftUI

/// Edits one meal (always a copy-on-write copy when reached from the day view).
/// Quantity changes only set `item.quantity`; macros scale from the base values.
struct MealEditView: View {
    @Bindable var meal: MealDefinition

    @Environment(\.modelContext) private var context
    @State private var showCatalog = false
    @State private var showCustom = false

    private var slotOptions: [String] {
        MealSlot.all.contains(meal.slot) ? MealSlot.all : MealSlot.all + [meal.slot]
    }

    var body: some View {
        Form {
            Section("Meal") {
                TextField("Name", text: $meal.name)
                Picker("Slot", selection: $meal.slot) {
                    ForEach(slotOptions, id: \.self) { slot in
                        Text(MealSlot.title(slot)).tag(slot)
                    }
                }
                TextField("Notes", text: $meal.notes, axis: .vertical)
            }

            Section {
                ForEach(meal.sortedItems) { item in
                    ItemEditRow(item: item)
                }
                .onDelete(perform: deleteItems)

                Button {
                    showCatalog = true
                } label: {
                    Label("Add ingredient", systemImage: "plus.circle.fill")
                }
                Button {
                    showCustom = true
                } label: {
                    Label("Add custom ingredient", systemImage: "square.and.pencil")
                }
            } header: {
                Text("Ingredients")
            } footer: {
                Text("Total \(meal.macros.kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit meal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCatalog) {
            CatalogPickerSheet { ingredient, quantity in
                addCatalogItem(ingredient, quantity: quantity)
            }
        }
        .sheet(isPresented: $showCustom) {
            CustomIngredientSheet { name, unit, quantity, macros in
                addCustomItem(name: name, unit: unit, quantity: quantity, macros: macros)
            }
        }
        .onDisappear { try? context.save() }
    }

    // MARK: - Changes

    private func deleteItems(at offsets: IndexSet) {
        let items = meal.sortedItems
        let remaining = items.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        for index in offsets {
            context.delete(items[index])
        }
        for (order, item) in remaining.enumerated() {
            item.order = order
        }
        try? context.save()
    }

    private func addCatalogItem(_ ingredient: CatalogIngredient, quantity: Double) {
        let macros = MacroMath.macros(catalog: ingredient.values, amount: quantity)
        insertItem(
            ingredientKey: ingredient.key,
            name: ingredient.name,
            unit: ingredient.unit,
            quantity: quantity,
            macros: macros
        )
    }

    private func addCustomItem(name: String, unit: String, quantity: Double, macros: Macros) {
        insertItem(ingredientKey: "", name: name, unit: unit, quantity: quantity, macros: macros)
    }

    private func insertItem(ingredientKey: String, name: String, unit: String, quantity: Double, macros: Macros) {
        let item = MealItem(
            order: meal.items.count,
            ingredientKey: ingredientKey,
            name: name,
            unit: unit,
            quantity: quantity,
            baseQuantity: quantity,
            baseKcal: macros.kcal,
            baseProtein: macros.protein,
            baseCarbs: macros.carbs,
            baseFat: macros.fat,
            baseFibre: macros.fibre
        )
        context.insert(item)
        item.meal = meal
        try? context.save()
    }
}

// MARK: - Ingredient row

private struct ItemEditRow: View {
    @Bindable var item: MealItem

    @State private var expanded = false
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fibre: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $item.name)
                .font(.headline)
            HStack {
                TextField("Quantity", value: $item.quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 90)
                    .textFieldStyle(.roundedBorder)
                Text(item.unit)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(item.macros.kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup("Edit macros", isExpanded: $expanded) {
                NumberField(title: "kcal", value: $kcal)
                NumberField(title: "Protein (g)", value: $protein)
                NumberField(title: "Carbs (g)", value: $carbs)
                NumberField(title: "Fat (g)", value: $fat)
                NumberField(title: "Fibre (g)", value: $fibre)
                Button("Apply", action: apply)
                    .buttonStyle(.borderless)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
        .onChange(of: expanded) { _, isOpen in
            if isOpen { load() }
        }
    }

    /// Shows the macros at the current quantity.
    private func load() {
        let macros = item.macros
        kcal = macros.kcal
        protein = macros.protein
        carbs = macros.carbs
        fat = macros.fat
        fibre = macros.fibre
    }

    /// The entered numbers become the base values at the current quantity.
    private func apply() {
        item.baseKcal = kcal ?? 0
        item.baseProtein = protein ?? 0
        item.baseCarbs = carbs ?? 0
        item.baseFat = fat ?? 0
        item.baseFibre = fibre ?? 0
        item.baseQuantity = item.quantity
        expanded = false
    }
}

/// A labelled decimal field.
private struct NumberField: View {
    let title: String
    @Binding var value: Double?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
        }
    }
}

// MARK: - Catalog picker

private struct CatalogPickerSheet: View {
    let onAdd: (CatalogIngredient, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CatalogIngredient.name) private var catalog: [CatalogIngredient]
    @State private var search = ""

    private var results: [CatalogIngredient] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return catalog }
        return catalog.filter { $0.name.localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        NavigationStack {
            List(results) { ingredient in
                NavigationLink {
                    CatalogQuantityView(ingredient: ingredient) { quantity in
                        onAdd(ingredient, quantity)
                        dismiss()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name)
                        Text(ingredient.unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, prompt: "Search ingredients")
            .navigationTitle("Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Asks how much of the chosen catalog ingredient to add.
private struct CatalogQuantityView: View {
    let ingredient: CatalogIngredient
    let onConfirm: (Double) -> Void

    @State private var quantity: Double?

    init(ingredient: CatalogIngredient, onConfirm: @escaping (Double) -> Void) {
        self.ingredient = ingredient
        self.onConfirm = onConfirm
        _quantity = State(initialValue: ingredient.unit == "pcs" ? 1 : 100)
    }

    private var amount: Double { quantity ?? 0 }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Quantity")
                    Spacer()
                    TextField("0", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                    Text(ingredient.unit)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Macros") {
                let macros = MacroMath.macros(catalog: ingredient.values, amount: amount)
                LabeledContent("kcal", value: macros.kcal.formatted(.number.precision(.fractionLength(0))))
                LabeledContent("Protein", value: gramText(macros.protein))
                LabeledContent("Carbs", value: gramText(macros.carbs))
                LabeledContent("Fat", value: gramText(macros.fat))
                LabeledContent("Fibre", value: gramText(macros.fibre))
            }
        }
        .navigationTitle(ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { onConfirm(amount) }
                    .disabled(amount <= 0)
            }
        }
    }

    private func gramText(_ grams: Double) -> String {
        "\(grams.formatted(.number.precision(.fractionLength(0...1)))) g"
    }
}

// MARK: - Custom ingredient

private struct CustomIngredientSheet: View {
    let onAdd: (String, String, Double, Macros) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var unit = "g"
    @State private var quantity: Double?
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fibre: Double?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        !trimmedName.isEmpty && (quantity ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                    Picker("Unit", selection: $unit) {
                        ForEach(["g", "ml", "pcs"], id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    NumberField(title: "Quantity (\(unit))", value: $quantity)
                }
                Section {
                    NumberField(title: "kcal", value: $kcal)
                    NumberField(title: "Protein (g)", value: $protein)
                    NumberField(title: "Carbs (g)", value: $carbs)
                    NumberField(title: "Fat (g)", value: $fat)
                    NumberField(title: "Fibre (g)", value: $fibre)
                } header: {
                    Text("Macros for this quantity")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Custom ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let macros = Macros(
                            kcal: kcal ?? 0,
                            protein: protein ?? 0,
                            carbs: carbs ?? 0,
                            fat: fat ?? 0,
                            fibre: fibre ?? 0
                        )
                        onAdd(trimmedName, unit, quantity ?? 0, macros)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}
