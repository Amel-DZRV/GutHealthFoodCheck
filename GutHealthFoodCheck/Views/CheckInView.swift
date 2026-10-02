import SwiftData
import SwiftUI

/// The evening check-in. A new check-in is assigned to the program's next day
/// (baseline, test or settling) when saved; editing keeps that assignment.
struct CheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [ProgramSettings]
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @Query(sort: \ReintroTest.order) private var tests: [ReintroTest]

    private let existing: DailyCheckIn?

    @State private var date: Date
    @State private var bloating: Int
    @State private var gas: Int
    @State private var pain: Int
    @State private var stool: BristolType
    @State private var stoppedTest: Bool
    @State private var notes: String
    @State private var confirmingDelete = false

    init(existing: DailyCheckIn?) {
        self.existing = existing
        _date = State(initialValue: existing?.day ?? .now)
        _bloating = State(initialValue: existing?.bloating ?? 0)
        _gas = State(initialValue: existing?.gas ?? 0)
        _pain = State(initialValue: existing?.pain ?? 0)
        _stool = State(initialValue: existing?.stool ?? .notRecorded)
        _stoppedTest = State(initialValue: existing?.stoppedTest ?? false)
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.badge)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(phase.title)
                            .font(.headline)
                    }
                    if existing == nil {
                        DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                        if dayAlreadyLogged {
                            Label("This day is already logged. Edit it from Today instead.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    RatingPicker(title: "Bloating", value: $bloating)
                    RatingPicker(title: "Gas", value: $gas)
                } header: {
                    Text("Over the whole day")
                } footer: {
                    if let stats = engine.baseline, engine.settings?.reintroStart != nil {
                        Text("Baseline average: bloating \(format(stats.bloating)), gas \(format(stats.gas)).")
                    }
                }

                Section("Optional") {
                    RatingPicker(title: "Abdominal pain", value: $pain)
                    Picker("Stool", selection: $stool) {
                        ForEach(BristolType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                if phase.isTesting {
                    Section {
                        if engine.isReaction(bloating: bloating, gas: gas) {
                            Label("This counts as a reaction. The test stops and you go back to a plain lunch.", systemImage: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                        }
                        Toggle("I reacted, stop this test", isOn: $stoppedTest)
                    } footer: {
                        Text("A test stops automatically when bloating or gas is 2 or more above your baseline.")
                    }
                }

                Section("Notes") {
                    TextField("Stress, sleep, exercise, period, anything unusual…", text: $notes, axis: .vertical)
                }

                if existing != nil {
                    Section {
                        Button("Delete Check-in", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Evening Check-in" : "Edit Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(existing == nil && dayAlreadyLogged)
                }
            }
            .confirmationDialog("Delete this check-in?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text("Test results and the plan are recalculated without it.")
            }
        }
    }

    private var engine: ProgramEngine {
        ProgramEngine(settings: settingsList.first, checkIns: checkIns, tests: tests)
    }

    private var phase: ProgramPhase {
        if let existing {
            return engine.phase(for: existing)
        }
        return engine.nextPhase(on: date)
    }

    private var dayAlreadyLogged: Bool {
        engine.checkIn(on: date) != nil
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private func save() {
        let assigned = phase
        let checkIn: DailyCheckIn
        if let existing {
            checkIn = existing
        } else {
            checkIn = DailyCheckIn(day: date, kind: assigned.kind, test: assigned.test, testDay: assigned.testDay)
            context.insert(checkIn)
        }
        checkIn.bloating = bloating
        checkIn.gas = gas
        checkIn.pain = pain
        checkIn.stoolRaw = stool.rawValue
        checkIn.stoppedTest = assigned.isTesting && stoppedTest
        checkIn.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ProgramActions.didChange(context)
        dismiss()
    }

    private func delete() {
        if let existing {
            context.delete(existing)
            ProgramActions.didChange(context)
        }
        dismiss()
    }
}
