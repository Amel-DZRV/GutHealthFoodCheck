import SwiftData
import SwiftUI

/// Adds or edits one food in the reintroduction plan.
struct TestEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let test: ReintroTest?
    private let nextOrder: Int

    @State private var name: String
    @State private var group: String
    @State private var category: FODMAPCategory
    @State private var amount: Double?
    @State private var unit: PortionUnit
    @State private var portionNote: String
    @State private var howToAdd: String
    @State private var durationDays: Int
    @State private var confirmingDelete = false

    init(test: ReintroTest?, nextOrder: Int) {
        self.test = test
        self.nextOrder = nextOrder
        _name = State(initialValue: test?.name ?? "")
        _group = State(initialValue: test?.group ?? "")
        _category = State(initialValue: test?.category ?? .mixed)
        _amount = State(initialValue: test?.amount)
        _unit = State(initialValue: test?.unit ?? .grams)
        _portionNote = State(initialValue: test?.portionNote ?? "")
        _howToAdd = State(initialValue: test?.howToAdd ?? "on the side")
        _durationDays = State(initialValue: test?.durationDays ?? 3)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name, e.g. Onion", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Group, e.g. Fruit", text: $group)
                        .textInputAutocapitalization(.words)
                    Picker("FODMAP group", selection: $category) {
                        ForEach(FODMAPCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Amount", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $unit) {
                            ForEach(PortionUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                    TextField("Label (optional), e.g. 1 clove", text: $portionNote)
                    TextField("How it's added to lunch", text: $howToAdd, axis: .vertical)
                    Stepper("Test for \(durationDays) days", value: $durationDays, in: 1...14)
                } header: {
                    Text("Portion")
                } footer: {
                    Text("Name + amount must match a food in the Foods list for the result to be recorded there; otherwise it's added.")
                }

                if let test, test.checkIns.isEmpty {
                    Section {
                        Button("Delete from Plan", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(test == nil ? "Add Test" : "Edit Test")
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
            .confirmationDialog("Delete this test?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && (amount ?? 0) > 0
    }

    private func save() {
        guard canSave, let amount else { return }
        let target = test ?? {
            let new = ReintroTest(order: nextOrder, name: trimmedName, group: "", category: category, amount: amount, unit: unit, howToAdd: "")
            context.insert(new)
            return new
        }()
        target.name = trimmedName
        target.group = group.trimmingCharacters(in: .whitespacesAndNewlines)
        target.category = category
        target.amount = amount
        target.unit = unit
        target.portionNote = portionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        target.howToAdd = howToAdd.trimmingCharacters(in: .whitespacesAndNewlines)
        target.durationDays = durationDays
        ProgramActions.didChange(context)
        dismiss()
    }

    private func delete() {
        if let test {
            context.delete(test)
            ProgramActions.didChange(context)
        }
        dismiss()
    }
}
