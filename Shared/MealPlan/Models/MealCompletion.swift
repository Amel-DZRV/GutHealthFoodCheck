import Foundation
import SwiftData

/// Presence means the meal was eaten on that date.
@Model
final class MealCompletion {
    var person: String = ""
    /// startOfDay
    var date: Date = Date()
    var mealKey: String = ""

    init(person: String = "", date: Date = Date(), mealKey: String = "") {
        self.person = person
        self.date = date
        self.mealKey = mealKey
    }
}
