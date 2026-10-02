import Foundation
import SwiftData

/// What a day counted as in the program, fixed when the check-in is saved.
enum CheckInKind: String {
    case baseline
    case test
    case settling
    case free
}

/// The evening log: how bloating and gas were over the whole day.
@Model
final class DailyCheckIn {
    /// Start of the calendar day this check-in covers.
    var day: Date = Date()
    /// 0–5
    var bloating: Int = 0
    /// 0–5
    var gas: Int = 0
    /// 0–5
    var pain: Int = 0
    var stoolRaw: Int = 0
    var notes: String = ""
    var kindRaw: String = CheckInKind.baseline.rawValue
    /// 1-based day within the test block, for `.test` check-ins.
    var testDay: Int = 0
    /// You stopped the test yourself, whatever the scores.
    var stoppedTest: Bool = false
    /// The food tested that day, or for `.settling` the food that caused the reaction.
    var test: ReintroTest?

    init(day: Date, kind: CheckInKind, test: ReintroTest?, testDay: Int) {
        self.day = Calendar.current.startOfDay(for: day)
        self.kindRaw = kind.rawValue
        self.test = test
        self.testDay = testDay
    }

    var kind: CheckInKind { CheckInKind(rawValue: kindRaw) ?? .free }
    var stool: BristolType { BristolType(rawValue: stoolRaw) ?? .notRecorded }
}
