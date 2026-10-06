import Foundation
import SwiftData

/// A date whose meal list differs from the plan.
@Model
final class DayOverride {
    var person: String = ""
    /// startOfDay
    var date: Date = Date()
    /// Ordered meal keys.
    var mealKeys: [String] = []

    init(person: String = "", date: Date = Date(), mealKeys: [String] = []) {
        self.person = person
        self.date = date
        self.mealKeys = mealKeys
    }

    var snapshot: DayOverrideSnapshot {
        DayOverrideSnapshot(person: person, date: date, mealKeys: mealKeys)
    }
}
