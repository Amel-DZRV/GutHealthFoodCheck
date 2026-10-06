import Foundation
import SwiftData

/// One ingredient line of a meal. `base*` hold the macros at `baseQuantity`; they scale with `quantity`.
@Model
final class MealItem {
    var order: Int = 0
    var ingredientKey: String = ""
    var name: String = ""
    var unit: String = "g"
    var quantity: Double = 0
    var baseQuantity: Double = 0
    var baseKcal: Double = 0
    var baseProtein: Double = 0
    var baseCarbs: Double = 0
    var baseFat: Double = 0
    var baseFibre: Double = 0
    var component: String = ""
    /// "", "raw", "cooked", "dry", "drained"
    var state: String = ""
    var note: String = ""
    var meal: MealDefinition?

    init(
        order: Int = 0,
        ingredientKey: String = "",
        name: String = "",
        unit: String = "g",
        quantity: Double = 0,
        baseQuantity: Double = 0,
        baseKcal: Double = 0,
        baseProtein: Double = 0,
        baseCarbs: Double = 0,
        baseFat: Double = 0,
        baseFibre: Double = 0,
        component: String = "",
        state: String = "",
        note: String = ""
    ) {
        self.order = order
        self.ingredientKey = ingredientKey
        self.name = name
        self.unit = unit
        self.quantity = quantity
        self.baseQuantity = baseQuantity
        self.baseKcal = baseKcal
        self.baseProtein = baseProtein
        self.baseCarbs = baseCarbs
        self.baseFat = baseFat
        self.baseFibre = baseFibre
        self.component = component
        self.state = state
        self.note = note
    }

    var baseMacros: Macros {
        Macros(kcal: baseKcal, protein: baseProtein, carbs: baseCarbs, fat: baseFat, fibre: baseFibre)
    }

    var macros: Macros {
        MacroMath.current(base: baseMacros, baseQuantity: baseQuantity, quantity: quantity)
    }
}
