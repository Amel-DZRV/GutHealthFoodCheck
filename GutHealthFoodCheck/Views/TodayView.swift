import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [ProgramSettings]
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @Query(sort: \ReintroTest.order) private var tests: [ReintroTest]
    @Query private var planEntries: [PlanEntry]
    @Query private var overrides: [DayOverride]
    @Query private var allMeals: [MealDefinition]
    @Query private var completions: [MealCompletion]
    @Query private var allTargets: [PersonTargets]
    @Query private var mealSettingsList: [MealPlanSettings]
    @Bindable private var router = AppRouter.shared

    @State private var editing: DailyCheckIn?
    @State private var showingSettings = false
    @State private var showingShopping = false
    @State private var confirmingStart = false
    @State private var date = Calendar.current.startOfDay(for: .now)

    private let person = Profile.amel.rawValue

    var body: some View {
        NavigationStack {
            List {
                if let settings = settingsList.first {
                    content(settings: settings)
                }
            }
            .navigationTitle("Today")
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                date = Calendar.current.startOfDay(for: .now)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingShopping = true
                    } label: {
                        Label("Shopping list", systemImage: "cart")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(for: String.self) { key in
                MealDetailView(
                    mealKey: key,
                    person: person,
                    date: date,
                    testAddition: testAddition(forMealKey: key)
                )
            }
            .sheet(isPresented: $showingSettings) {
                ProgramSettingsView()
            }
            .sheet(isPresented: $showingShopping) {
                ShoppingListView(profile: .amel)
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

    /// Everything the meal plan shows for the selected day.
    private struct MealDay {
        let resolved: ResolvedDay
        let meals: [MealDefinition]
        let eatenKeys: Set<String>
        let summary: DaySummary
    }

    private var isMealPlanImported: Bool {
        mealSettingsList.first?.importedAt != nil
    }

    private func buildMealDay() -> MealDay {
        let day = Calendar.current.startOfDay(for: date)
        let resolved = MealResolver.resolve(
            person: person,
            date: day,
            rotationStart: mealSettingsList.first?.rotationStart ?? day,
            entries: planEntries.filter { $0.person == person }.map(\.snapshot),
            overrides: overrides.filter { $0.person == person }.map(\.snapshot)
        )
        let meals = resolved.mealKeys.compactMap { key in allMeals.first { $0.key == key } }
        let eatenKeys = Set(
            completions
                .filter { $0.person == person && Calendar.current.startOfDay(for: $0.date) == day }
                .map(\.mealKey)
        )
        let target = allTargets.first { $0.person == person }?.snapshot
            ?? TargetsSnapshot(kcal: 2250, proteinMin: 200, proteinMax: nil, carbs: nil, fat: nil, fibre: nil)
        let summary = DaySummaryBuilder.build(
            meals: meals.map { ($0.key, $0.macros) },
            eatenKeys: eatenKeys,
            target: target
        )
        return MealDay(resolved: resolved, meals: meals, eatenKeys: eatenKeys, summary: summary)
    }

    /// The test food added to lunch on the selected day, if any.
    private func testAddition(forMealKey key: String) -> String? {
        guard allMeals.first(where: { $0.key == key })?.slot == "lunch" else { return nil }
        return lunchTestAddition()
    }

    private func lunchTestAddition() -> String? {
        let engine = self.engine
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        if day == today {
            let phase = engine.phase(on: .now)
            guard phase.isTesting, let test = phase.test else { return nil }
            return "\(test.name) \(test.instruction)"
        }
        if day < today {
            guard let checkIn = engine.checkIn(on: day), checkIn.kind == .test, let test = checkIn.test else { return nil }
            return "\(test.name) \(test.instruction)"
        }
        return nil
    }

    private func toggleEaten(_ key: String) {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = completions.first(where: {
            $0.person == person && $0.mealKey == key && Calendar.current.startOfDay(for: $0.date) == day
        }) {
            context.delete(existing)
        } else {
            context.insert(MealCompletion(person: person, date: day, mealKey: key))
        }
        try? context.save()
    }

    @ViewBuilder
    private func mealsSection(_ mealDay: MealDay, isToday: Bool) -> some View {
        Section(isToday ? "Today's meals" : "Meals") {
            if mealDay.meals.isEmpty {
                Text("No meals planned for this day.")
                    .foregroundStyle(.secondary)
            }
            ForEach(mealDay.meals) { meal in
                NavigationLink(value: meal.key) {
                    MealRowView(
                        title: MealSlot.title(meal.slot),
                        name: meal.name,
                        summary: meal.itemSummary,
                        kcal: meal.macros.kcal,
                        isEaten: mealDay.eatenKeys.contains(meal.key),
                        testAddition: meal.slot == "lunch" ? lunchTestAddition() : nil,
                        onToggle: { toggleEaten(meal.key) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func content(settings: ProgramSettings) -> some View {
        let engine = self.engine
        let phase = engine.phase(on: .now)
        let todaysCheckIn = engine.checkIn(on: .now)
        let mealDay: MealDay? = isMealPlanImported ? buildMealDay() : nil
        // Without the meal plan there is no day picker, so the screen is always today.
        let isToday = mealDay == nil || Calendar.current.isDateInToday(date)

        Section {
            PhaseCard(phase: phase)
        }

        if let mealDay {
            Section {
                DayHeaderView(date: $date, training: mealDay.resolved.training)
                DaySummaryCard(summary: mealDay.summary)
            }
        }

        if isToday {
            checkInSection(todaysCheckIn: todaysCheckIn, phase: phase)
        }

        if let mealDay {
            mealsSection(mealDay, isToday: isToday)
        } else {
            Section("Today's meals") {
                MealRow(title: "Breakfast", text: settings.breakfast)
                MealRow(title: "Lunch", text: settings.lunch, addition: phase.isTesting ? phase.test : nil)
                MealRow(title: "Dinner", text: settings.dinner)
            }
        }

        if isToday && settings.reintroStart == nil {
            baselineSection(engine: engine)
        }

        if isToday && !checkIns.isEmpty {
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
    private func checkInSection(todaysCheckIn: DailyCheckIn?, phase: ProgramPhase) -> some View {
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
