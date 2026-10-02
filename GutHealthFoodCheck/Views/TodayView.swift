import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [ProgramSettings]
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @Query(sort: \ReintroTest.order) private var tests: [ReintroTest]
    @Bindable private var router = AppRouter.shared

    @State private var editing: DailyCheckIn?
    @State private var showingSettings = false
    @State private var confirmingStart = false

    var body: some View {
        NavigationStack {
            List {
                if let settings = settingsList.first {
                    content(settings: settings)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ProgramSettingsView()
            }
            .sheet(isPresented: $router.showCheckIn) {
                CheckInView(existing: engine.checkIn(on: .now))
            }
            .sheet(item: $editing) { checkIn in
                CheckInView(existing: checkIn)
            }
            .alert("Start reintroduction?", isPresented: $confirmingStart) {
                Button("Start") { ProgramActions.startReintroduction(context) }
                Button("Not yet", role: .cancel) {}
            } message: {
                Text("Baseline days stop counting. From your next check-in, lunch includes the first test food.")
            }
        }
    }

    private var engine: ProgramEngine {
        ProgramEngine(settings: settingsList.first, checkIns: checkIns, tests: tests)
    }

    @ViewBuilder
    private func content(settings: ProgramSettings) -> some View {
        let engine = self.engine
        let phase = engine.phase(on: .now)
        let todaysCheckIn = engine.checkIn(on: .now)

        Section {
            PhaseCard(phase: phase)
        }

        Section("Evening check-in") {
            if let todaysCheckIn {
                Button {
                    editing = todaysCheckIn
                } label: {
                    CheckInRow(checkIn: todaysCheckIn, phase: phase, showsDate: false)
                }
                .foregroundStyle(.primary)
            } else {
                Button {
                    router.showCheckIn = true
                } label: {
                    Label("Log today's bloating and gas", systemImage: "square.and.pencil")
                        .font(.headline)
                }
            }
        }

        Section("Today's meals") {
            MealRow(title: "Breakfast", text: settings.breakfast)
            MealRow(title: "Lunch", text: settings.lunch, addition: phase.isTesting ? phase.test : nil)
            MealRow(title: "Dinner", text: settings.dinner)
        }

        if settings.reintroStart == nil {
            baselineSection(engine: engine)
        }

        if !checkIns.isEmpty {
            Section("Recent days") {
                ForEach(Array(checkIns.reversed().prefix(14))) { checkIn in
                    Button {
                        editing = checkIn
                    } label: {
                        CheckInRow(checkIn: checkIn, phase: engine.phase(for: checkIn), showsDate: true)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func baselineSection(engine: ProgramEngine) -> some View {
        let logged = engine.baselineCheckIns.count
        Section {
            ProgressView(value: Double(min(logged, ProgramRules.baselineDays)), total: Double(ProgramRules.baselineDays)) {
                Text("\(min(logged, ProgramRules.baselineDays)) of \(ProgramRules.baselineDays) baseline days logged")
            }
            if let stats = engine.baseline {
                LabeledContent("Average bloating", value: stats.bloating.formatted(.number.precision(.fractionLength(1))))
                LabeledContent("Average gas", value: stats.gas.formatted(.number.precision(.fractionLength(1))))
            }
            if logged >= ProgramRules.baselineDays, let stats = engine.baseline {
                if stats.isStable {
                    Label("Your baseline looks calm. You're ready to start testing.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(
                        "Some baseline days scored above \(ProgramRules.stableBaselineMax). Consider a few more baseline days before testing.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
                Button("Start reintroduction") { confirmingStart = true }
                    .font(.headline)
            }
        } header: {
            Text("Baseline week")
        } footer: {
            Text("Test days count as a reaction when bloating or gas is 2 or more above your baseline average.")
        }
    }
}

private struct PhaseCard: View {
    let phase: ProgramPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(phase.badge)
                .font(.caption.bold())
                .foregroundStyle(tint)
            Text(phase.title)
                .font(.title.bold())
            Text(phase.detail)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var tint: Color {
        switch phase {
        case .testing: .blue
        case .settling: .orange
        case .complete, .baselineDone: .green
        default: .secondary
        }
    }
}

private struct MealRow: View {
    let title: String
    let text: String
    var addition: ReintroTest? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(text.isEmpty ? "Set your standard \(title.lowercased()) in Settings" : text)
                .font(.subheadline)
                .foregroundStyle(text.isEmpty ? HierarchicalShapeStyle.tertiary : HierarchicalShapeStyle.secondary)
            if let addition {
                Label("\(addition.name) \(addition.instruction)", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CheckInRow: View {
    let checkIn: DailyCheckIn
    let phase: ProgramPhase
    let showsDate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if showsDate {
                    Text(checkIn.day, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.subheadline.bold())
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 6) {
                Chip(text: "Bloating \(checkIn.bloating)", color: .forScore(Double(checkIn.bloating)))
                Chip(text: "Gas \(checkIn.gas)", color: .forScore(Double(checkIn.gas)))
                if checkIn.pain > 0 {
                    Chip(text: "Pain \(checkIn.pain)", color: .forScore(Double(checkIn.pain)))
                }
                if checkIn.stool != .notRecorded {
                    Chip(text: checkIn.stool.shortTitle, color: checkIn.stool.isNormal ? .green : .orange)
                }
            }
            if !checkIn.notes.isEmpty {
                Text(checkIn.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var label: String {
        switch phase {
        case let .testing(test, day): "\(test.name) · day \(day)/\(test.durationDays)"
        case .settling: "Settling"
        case let .baseline(day, _): "Baseline day \(day)"
        default: phase.title
        }
    }
}
