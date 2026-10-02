import Foundation
import SwiftData

/// One food in the reintroduction plan, eaten with lunch for `durationDays` testing days.
@Model
final class ReintroTest {
    var order: Int = 0
    var name: String = ""
    /// The plan's own grouping, e.g. "Fruit" or "Nut".
    var group: String = ""
    var categoryRaw: String = "mixed"
    var amount: Double = 0
    var unitRaw: String = "g"
    /// Overrides the amount label, e.g. "1 clove".
    var portionNote: String = ""
    /// How it goes into lunch, e.g. "cooked, in with the protein".
    var howToAdd: String = ""
    var durationDays: Int = 3
    var isSkipped: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \DailyCheckIn.test)
    var checkIns: [DailyCheckIn] = []

    init(
        order: Int,
        name: String,
        group: String,
        category: FODMAPCategory,
        amount: Double,
        unit: PortionUnit,
        portionNote: String = "",
        howToAdd: String,
        durationDays: Int = 3
    ) {
        self.order = order
        self.name = name
        self.group = group
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.unitRaw = unit.rawValue
        self.portionNote = portionNote
        self.howToAdd = howToAdd
        self.durationDays = durationDays
    }

    var category: FODMAPCategory {
        get { FODMAPCategory(rawValue: categoryRaw) ?? .mixed }
        set { categoryRaw = newValue.rawValue }
    }

    var unit: PortionUnit {
        get { PortionUnit(rawValue: unitRaw) ?? .grams }
        set { unitRaw = newValue.rawValue }
    }

    var amountLabel: String {
        if !portionNote.isEmpty { return portionNote }
        return "~\(amount.formatted(.number.precision(.fractionLength(0...1)))) \(unit.rawValue)"
    }

    /// "~30 g, cooked, in with the protein"
    var instruction: String {
        howToAdd.isEmpty ? amountLabel : "\(amountLabel), \(howToAdd)"
    }
}
