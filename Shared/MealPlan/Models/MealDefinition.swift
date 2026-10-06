import Foundation
import SwiftData

/// A meal: either an imported template or a copy-on-write copy for one date.
@Model
final class MealDefinition {
    /// json meals[].id; copies are "<key>@yyyy-MM-dd"
    var key: String = ""
    /// "amel" | "nina"
    var person: String = ""
    /// "breakfast", "lunch", "pre_workout", "dinner", "snack"
    var slot: String = ""
    var name: String = ""
    var notes: String = ""
    /// false for copy-on-write copies
    var isTemplate: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal)
    var items: [MealItem] = []
    @Relationship(deleteRule: .cascade, inverse: \MealStep.meal)
    var steps: [MealStep] = []

    init(
        key: String = "",
        person: String = "",
        slot: String = "",
        name: String = "",
        notes: String = "",
        isTemplate: Bool = true
    ) {
        self.key = key
        self.person = person
        self.slot = slot
        self.name = name
        self.notes = notes
        self.isTemplate = isTemplate
    }

    var sortedItems: [MealItem] { items.sorted { $0.order < $1.order } }
    var sortedSteps: [MealStep] { steps.sorted { $0.order < $1.order } }

    /// Sum of the current macros of all items.
    var macros: Macros {
        items.reduce(Macros.zero) { $0 + $1.macros }
    }

    /// First three item names, e.g. "Eggs + Butter + Skyr …" when there are more.
    var itemSummary: String {
        let names = sortedItems.map(\.name)
        guard !names.isEmpty else { return "" }
        let summary = names.prefix(3).joined(separator: " + ")
        return names.count > 3 ? summary + " …" : summary
    }
}
