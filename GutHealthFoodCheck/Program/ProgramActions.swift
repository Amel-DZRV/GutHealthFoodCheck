import Foundation
import SwiftData
import WidgetKit

@MainActor
enum ProgramActions {
    /// Creates the settings and the default test plan on first launch.
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ProgramSettings>())) ?? 0
        guard count == 0 else { return }
        context.insert(ProgramSettings(baselineStart: DefaultPlan.nextMonday(), lunch: DefaultPlan.lunch))
        for test in DefaultPlan.makeTests() {
            context.insert(test)
        }
        try? context.save()
    }

    /// Call after any change to check-ins, tests or settings.
    static func didChange(_ context: ModelContext) {
        try? context.save()
        syncResultsToFoods(context)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        refreshReminders(context)
    }

    static func refreshReminders(_ context: ModelContext) {
        let engine = SharedStore.engine(context)
        let today = Date.now
        let phase = engine.phase(on: today)
        let loggedToday = engine.checkIn(on: today) != nil
        Task {
            await ReminderScheduler.reschedule(loggedToday: loggedToday, todayTitle: phase.title)
        }
    }

    static func startReintroduction(_ context: ModelContext) {
        guard let settings = try? context.fetch(FetchDescriptor<ProgramSettings>()).first else { return }
        settings.reintroStart = Calendar.current.startOfDay(for: .now)
        didChange(context)
    }

    /// Writes finished test results onto the matching food (name + portion) in the Foods list.
    private static func syncResultsToFoods(_ context: ModelContext) {
        let engine = SharedStore.engine(context)
        let foods = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []

        for test in engine.tests {
            let match = foods.first { $0.isSameFood(name: test.name, portion: test.amount, unit: test.unit) }
            let result: (raw: String, detail: String)?
            switch engine.outcome(of: test) {
            case .tolerated:
                result = ("tolerated", "Tolerated all \(test.durationDays) test days (\(test.amountLabel)).")
            case let .reaction(day):
                result = ("reaction", "Reaction on test day \(day) of \(test.durationDays) (\(test.amountLabel)).")
            default:
                result = nil
            }

            if let result {
                let food = match ?? {
                    let item = FoodItem(name: test.name, portion: test.amount, unit: test.unit, category: test.category)
                    context.insert(item)
                    return item
                }()
                food.reintroResultRaw = result.raw
                food.reintroDetail = result.detail
            } else if let match, !match.reintroResultRaw.isEmpty {
                match.reintroResultRaw = ""
                match.reintroDetail = ""
            }
        }
    }
}
