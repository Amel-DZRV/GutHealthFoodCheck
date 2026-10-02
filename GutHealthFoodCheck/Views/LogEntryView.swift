import SwiftData
import SwiftUI

/// Records one reaction to a food. Expects to be inside a NavigationStack.
struct LogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let food: FoodItem
    /// Called after saving instead of dismissing; lets a parent sheet close itself.
    var onSaved: (() -> Void)? = nil

    @State private var draft = SymptomDraft()

    var body: some View {
        Form {
            Section {
                LabeledContent(food.name, value: food.portionLabel)
            }
            SymptomFields(draft: $draft)
        }
        .navigationTitle("Log Reaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSaved == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
    }

    private func save() {
        let log = draft.makeLog()
        context.insert(log)
        log.food = food
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}

/// The symptom form sections, shared by "Add Food" and "Log Reaction".
struct SymptomFields: View {
    @Binding var draft: SymptomDraft

    var body: some View {
        Section("When") {
            DatePicker("Eaten at", selection: $draft.date)
            Picker("Symptoms started", selection: $draft.onset) {
                ForEach(OnsetTime.allCases) { onset in
                    Text(onset.title).tag(onset)
                }
            }
        }

        Section("Symptoms") {
            ScoreSlider(title: "Bloating", value: $draft.bloating)
            ScoreSlider(title: "Abdominal pain", value: $draft.pain)
            Picker("Gas", selection: $draft.gas) {
                ForEach(GasLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            Picker("Stool", selection: $draft.stool) {
                ForEach(BristolType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
        }

        Section {
            TextField("e.g. rice 150 g, chicken 120 g", text: $draft.eatenWith, axis: .vertical)
        } header: {
            Text("Eaten with")
        } footer: {
            Text("FODMAPs from different foods add up, so note the rest of the meal.")
        }

        Section("Notes") {
            TextField("Stress, sleep, exercise, period…", text: $draft.notes, axis: .vertical)
        }
    }
}

private struct ScoreSlider: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value) / 10")
                    .monospacedDigit()
                    .bold()
                    .foregroundStyle(Color.forScore(Double(value)))
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(Color.forScore(Double(value)))
            .accessibilityLabel(title)
            .accessibilityValue("\(value) out of 10")
        }
    }
}
