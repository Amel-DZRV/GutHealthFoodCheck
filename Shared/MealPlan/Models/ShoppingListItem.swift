import Foundation
import SwiftData

/// One line of the shopping list, generated from the plan or added by hand.
@Model
final class ShoppingListItem {
    var name: String = ""
    var quantity: Double = 0
    var unit: String = ""
    var aisle: String = "other"
    var order: Int = 0
    var isChecked: Bool = false
    var isManual: Bool = false
    /// Ingredient key for generated items.
    var sourceKey: String = ""

    init(
        name: String = "",
        quantity: Double = 0,
        unit: String = "",
        aisle: String = "other",
        order: Int = 0,
        isChecked: Bool = false,
        isManual: Bool = false,
        sourceKey: String = ""
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisle = aisle
        self.order = order
        self.isChecked = isChecked
        self.isManual = isManual
        self.sourceKey = sourceKey
    }
}
