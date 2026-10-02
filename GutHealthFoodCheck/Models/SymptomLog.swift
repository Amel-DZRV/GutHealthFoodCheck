import Foundation
import SwiftData

/// One occasion of eating a food and how your gut reacted afterwards.
@Model
final class SymptomLog {
    var date: Date = Date()
    /// 0–10
    var bloating: Int = 0
    var gasRaw: Int = 0
    /// 0–10
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
        gas: GasLevel,
        pain: Int,
        stool: BristolType,
        onset: OnsetTime,
        eatenWith: String,
        notes: String
    ) {
        self.date = date
        self.bloating = bloating
        self.gasRaw = gas.rawValue
        self.pain = pain
        self.stoolRaw = stool.rawValue
        self.onsetRaw = onset.rawValue
        self.eatenWith = eatenWith
        self.notes = notes
    }

    var gas: GasLevel { GasLevel(rawValue: gasRaw) ?? .absent }
    var stool: BristolType { BristolType(rawValue: stoolRaw) ?? .notRecorded }
    var onset: OnsetTime { OnsetTime(rawValue: onsetRaw) ?? .unknown }

    /// Worst of bloating, pain and gas on a 0–10 scale.
    var severity: Double {
        max(Double(bloating), Double(pain), gas.score)
    }
}

/// Editable, not-yet-saved values for a `SymptomLog`.
struct SymptomDraft {
    var date = Date()
    var bloating = 0
    var gas: GasLevel = .absent
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
