import Foundation

/// The meals (and training label) that apply to one person on one day.
struct ResolvedDay: Equatable {
    var date: Date
    var mealKeys: [String]
    var training: String
    var isOverride: Bool
}

/// Plain copy of a `PlanEntry`, so the resolver doesn't depend on SwiftData.
struct PlanEntrySnapshot: Equatable {
    var person: String
    var weekIndex: Int
    var weekday: Int
    var order: Int
    var mealKey: String
    var training: String
}

/// Plain copy of a `DayOverride`.
struct DayOverrideSnapshot: Equatable {
    var person: String
    var date: Date
    var mealKeys: [String]
}

enum MealResolver {
    /// entries/overrides are plain values copied from the models.
    static func resolve(person: String, date: Date, rotationStart: Date,
                        entries: [PlanEntrySnapshot], overrides: [DayOverrideSnapshot],
                        calendar: Calendar = .current) -> ResolvedDay {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)

        let weekIndex: Int
        if person == "nina" {
            let start = calendar.startOfDay(for: rotationStart)
            let days = calendar.dateComponents([.day], from: start, to: day).day ?? 0
            let weeks = Int(floor(Double(days) / 7))
            weekIndex = ((weeks % 2) + 2) % 2
        } else {
            weekIndex = 0
        }

        let planned = entries
            .filter { $0.person == person && $0.weekIndex == weekIndex && $0.weekday == weekday }
            .sorted { $0.order < $1.order }
        let training = planned.first?.training ?? ""

        if let override = overrides.first(where: {
            $0.person == person && calendar.startOfDay(for: $0.date) == day
        }) {
            return ResolvedDay(date: day, mealKeys: override.mealKeys, training: training, isOverride: true)
        }
        return ResolvedDay(date: day, mealKeys: planned.map(\.mealKey), training: training, isOverride: false)
    }
}
