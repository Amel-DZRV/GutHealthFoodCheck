import SwiftData
import SwiftUI

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [ProgramSettings]
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @Query(sort: \ReintroTest.order) private var tests: [ReintroTest]

    @State private var editingTest: ReintroTest?
    @State private var addingTest = false

    var body: some View {
        let engine = ProgramEngine(settings: settingsList.first, checkIns: checkIns, tests: tests)
        let next = engine.nextPhase(on: .now)
        let current = next.isTesting ? next.test : nil

        NavigationStack {
            List {
                Section {
                    summary(engine: engine)
                }

                Section {
                    ForEach(tests) { test in
                        Button {
                            editingTest = test
                        } label: {
                            TestRow(
                                test: test,
                                outcome: engine.outcome(of: test),
                                isCurrent: current?.persistentModelID == test.persistentModelID
                            )
                        }
                        .foregroundStyle(.primary)
                        .swipeActions {
                            Button(test.isSkipped ? "Unskip" : "Skip") {
                                test.isSkipped.toggle()
                                ProgramActions.didChange(context)
                            }
                            .tint(test.isSkipped ? Color.blue : Color.gray)
                        }
                    }
                    .onMove(perform: move)
                } header: {
                    Text("Test order")
                } footer: {
                    Text("Each food is added to lunch for 3 testing days (lactose 7). Days count only when you log them. After a reaction you eat a plain lunch until 2 calm days in a row, then the next food starts.")
                }
            }
            .navigationTitle("Reintroduction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addingTest = true
                    } label: {
                        Label("Add Test", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingTest) { test in
                TestEditView(test: test, nextOrder: tests.count)
            }
            .sheet(isPresented: $addingTest) {
                TestEditView(test: nil, nextOrder: tests.count)
            }
        }
    }

    @ViewBuilder
    private func summary(engine: ProgramEngine) -> some View {
        let outcomes = tests.map { engine.outcome(of: $0) }
        let tolerated = outcomes.filter { $0 == .tolerated }.count
        let reactions = outcomes.filter { if case .reaction = $0 { return true } else { return false } }.count
        let remaining = outcomes.filter { !$0.isFinished && $0 != .skipped }.count

        HStack {
            SummaryStat(value: tolerated, title: "Tolerated", color: .green)
            SummaryStat(value: reactions, title: "Reactions", color: .red)
            SummaryStat(value: remaining, title: "To go", color: .blue)
        }
        if let stats = engine.baseline {
            LabeledContent(
                "Baseline",
                value: "bloating \(stats.bloating.formatted(.number.precision(.fractionLength(1)))) · gas \(stats.gas.formatted(.number.precision(.fractionLength(1))))"
            )
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = tests
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, test) in reordered.enumerated() {
            test.order = index
        }
        ProgramActions.didChange(context)
    }
}

private struct SummaryStat: View {
    let value: Int
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TestRow: View {
    let test: ReintroTest
    let outcome: TestOutcome
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(test.order + 1)")
                .font(.caption.bold())
                .frame(width: 26, height: 26)
                .background(test.category.color.opacity(0.18), in: Circle())
                .foregroundStyle(test.category.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(test.name)
                    .font(.body.weight(isCurrent ? .bold : .regular))
                    .strikethrough(outcome == .skipped)
                Text("\(test.instruction) · \(test.category.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            status
        }
        .opacity(outcome == .skipped ? 0.5 : 1)
    }

    @ViewBuilder
    private var status: some View {
        switch outcome {
        case .pending:
            if isCurrent {
                StatusLabel(text: "Next", systemImage: "arrow.right.circle.fill", color: .blue)
            }
        case let .active(daysDone):
            StatusLabel(text: "Day \(daysDone + 1)/\(test.durationDays)", systemImage: "clock.fill", color: .blue)
        case .tolerated:
            StatusLabel(text: "Tolerated", systemImage: "checkmark.circle.fill", color: .green)
        case let .reaction(day):
            StatusLabel(text: "Reaction · day \(day)", systemImage: "xmark.octagon.fill", color: .red)
        case .skipped:
            StatusLabel(text: "Skipped", systemImage: "forward.fill", color: .gray)
        }
    }
}

private struct StatusLabel: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }
}
