import SwiftData
import SwiftUI

/// Editable cooking checklist for a meal. Edits the meal as shown (no copy-on-write),
/// so steps added to a template appear on every day that uses it.
struct StepsView: View {
    @Bindable var meal: MealDefinition

    @Environment(\.modelContext) private var context
    @State private var editingStep: MealStep?
    @State private var showAdd = false

    var body: some View {
        Group {
            if meal.steps.isEmpty {
                ContentUnavailableView {
                    Label("No steps yet", systemImage: "list.number")
                } description: {
                    Text("Add the steps you follow when cooking this meal.")
                } actions: {
                    Button("Add step") { showAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                stepList
            }
        }
        .navigationTitle("Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Uncheck all", systemImage: "circle", action: uncheckAll)
                        .disabled(!meal.steps.contains { $0.isDone })
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !meal.steps.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(item: $editingStep) { step in
            StepEditSheet(title: "Edit step", initialText: step.text) { text in
                saveEdit(step, text: text)
            }
        }
        .sheet(isPresented: $showAdd) {
            StepEditSheet(title: "Add step", initialText: "") { text in
                addStep(text: text)
            }
        }
    }

    private var stepList: some View {
        List {
            ForEach(meal.sortedSteps) { step in
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        step.isDone.toggle()
                        try? context.save()
                    } label: {
                        Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(step.isDone ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(step.isDone ? "Mark step as not done" : "Mark step as done")

                    Button {
                        editingStep = step
                    } label: {
                        Group {
                            if step.isDone {
                                Text(step.text)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(step.text)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: deleteSteps)
            .onMove(perform: moveSteps)

            Button {
                showAdd = true
            } label: {
                Label("Add step", systemImage: "plus.circle.fill")
            }
        }
    }

    // MARK: - Changes

    private func addStep(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let step = MealStep(order: meal.steps.count, text: trimmed)
        context.insert(step)
        step.meal = meal
        try? context.save()
    }

    /// An empty text deletes the step.
    private func saveEdit(_ step: MealStep, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let remaining = meal.sortedSteps.filter { $0 !== step }
            context.delete(step)
            renumber(remaining)
        } else {
            step.text = trimmed
        }
        try? context.save()
    }

    private func deleteSteps(at offsets: IndexSet) {
        let steps = meal.sortedSteps
        let doomed = offsets.map { steps[$0] }
        let remaining = steps.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        for step in doomed {
            context.delete(step)
        }
        renumber(remaining)
        try? context.save()
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        var steps = meal.sortedSteps
        steps.move(fromOffsets: source, toOffset: destination)
        renumber(steps)
        try? context.save()
    }

    private func uncheckAll() {
        for step in meal.steps {
            step.isDone = false
        }
        try? context.save()
    }

    /// Sets `order` to 0, 1, 2, … in the given sequence.
    private func renumber(_ steps: [MealStep]) {
        for (index, step) in steps.enumerated() {
            step.order = index
        }
    }
}

/// Multi-line text editor shared by "Add step" and editing a step.
private struct StepEditSheet: View {
    let title: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(title: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Step", text: $text, axis: .vertical)
                    .lineLimit(3...10)
                    .focused($focused)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
