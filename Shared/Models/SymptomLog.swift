import Foundation
import SwiftData

/// One occasion of eating a food and how your gut reacted afterwards.
@Model
final class SymptomLog {
    var date: Date = Date()
    /// 0–5
    var bloating: Int = 0
    /// 0–5
    var gas: Int = 0
    /// 0–5
    var pain: Int = 0
    var stoolRaw: Int = 0
    var onsetRaw: Int = 0
    /// Other foods (and portions) in the same meal. FODMAPs stack up.
    var eatenWith: String = ""
    var notes: String = ""
    var food: FoodItem?

    init(
        date: Date,
        bloating: Int,
        gas: Int,
        pain: Int,
        stool: BristolType,
        onset: OnsetTime,
        eatenWith: String,
        notes: String
    ) {
        self.date = date
        self.bloating = bloating
        self.gas = gas
        self.pain = pain
        self.stoolRaw = stool.rawValue
        self.onsetRaw = onset.rawValue
        self.eatenWith = eatenWith
        self.notes = notes
    }

    var stool: BristolType { BristolType(rawValue: stoolRaw) ?? .notRecorded }
    var onset: OnsetTime { OnsetTime(rawValue: onsetRaw) ?? .unknown }

    /// Worst of bloating, pain and gas.
    var severity: Double {
        Double(max(bloating, pain, gas))
    }
}

/// Editable, not-yet-saved values for a `SymptomLog`.
struct SymptomDraft {
    var date = Date()
    var bloating = 0
    var gas = 0
    var pain = 0
    var stool: BristolType = .notRecorded
    var onset: OnsetTime = .unknown
    var eatenWith = ""
    var notes = ""

    func makeLog() -> SymptomLog {
        SymptomLog(
            date: date,
            bloating: bloating,
            gas: gas,
            pain: pain,
            stool: stool,
            onset: onset,
            eatenWith: eatenWith.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
