import Foundation
import SwiftData

/// The single settings record for the baseline + reintroduction program.
@Model
final class ProgramSettings {
    var baselineStart: Date = Date()
    /// Set when you tap "Start reintroduction". Before that, every check-in is a baseline day.
    var reintroStart: Date?
    var breakfast: String = ""
    var lunch: String = ""
    var dinner: String = ""

    init(baselineStart: Date, breakfast: String = "", lunch: String = "", dinner: String = "") {
        self.baselineStart = Calendar.current.startOfDay(for: baselineStart)
        self.breakfast = breakfast
        self.lunch = lunch
        self.dinner = dinner
    }
}
