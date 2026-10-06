import Foundation

/// A set of nutrition numbers. Plain values so the logic doesn't depend on SwiftData.
struct Macros: Equatable {
    var kcal = 0.0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0
    var fibre = 0.0

    static let zero = Macros()

    static func + (a: Macros, b: Macros) -> Macros {
        Macros(
            kcal: a.kcal + b.kcal,
            protein: a.protein + b.protein,
            carbs: a.carbs + b.carbs,
            fat: a.fat + b.fat,
            fibre: a.fibre + b.fibre
        )
    }

    func scaled(by factor: Double) -> Macros {
        Macros(
            kcal: kcal * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            fibre: fibre * factor
        )
    }
}

/// Plain copy of catalog numbers so the logic doesn't depend on SwiftData.
struct CatalogValues {
    /// "per_100g" | "per_100ml" | "per_piece"
    var basis: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double
}

enum MacroMath {
    /// Macros for `amount` of a catalog item. per_100g / per_100ml scale by amount/100; per_piece by amount.
    static func macros(catalog: CatalogValues, amount: Double) -> Macros {
        let factor = catalog.basis == "per_piece" ? amount : amount / 100
        return Macros(
            kcal: catalog.kcal,
            protein: catalog.protein,
            carbs: catalog.carbs,
            fat: catalog.fat,
            fibre: catalog.fibre
        ).scaled(by: factor)
    }

    /// Current macros of an item: base × (quantity / baseQuantity). `.zero` if baseQuantity <= 0.
    static func current(base: Macros, baseQuantity: Double, quantity: Double) -> Macros {
        guard baseQuantity > 0 else { return .zero }
        return base.scaled(by: quantity / baseQuantity)
    }
}
