import Foundation
import SwiftData

/// One meal slot in the repeating plan.
@Model
final class PlanEntry {
    var person: String = ""
    /// amel: always 0; nina: 0 or 1
    var weekIndex: Int = 0
    /// Calendar weekday: 1 = Sunday ... 7 = Saturday
    var weekday: Int = 1
    /// Position within the day.
    var order: Int = 0
    var mealKey: String = ""
    /// amel only, e.g. "weightlifting"
    var training: String = ""

    init(
        person: String = "",
        weekIndex: Int = 0,
        weekday: Int = 1,
        order: Int = 0,
        mealKey: String = "",
        training: String = ""
    ) {
        self.person = person
        self.weekIndex = weekIndex
        self.weekday = weekday
        self.order = order
        self.mealKey = mealKey
        self.training = training
    }

    var snapshot: PlanEntrySnapshot {
        PlanEntrySnapshot(
            person: person,
            weekIndex: weekIndex,
            weekday: weekday,
            order: order,
            mealKey: mealKey,
            training: training
        )
    }
}
