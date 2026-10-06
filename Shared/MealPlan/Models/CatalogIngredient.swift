import Foundation
import SwiftData

/// One entry of the ingredient catalog (macros per 100 g, per 100 ml or per piece).
@Model
final class CatalogIngredient {
    /// json ingredients[].id, or "gf_bread_slice"
    var key: String = ""
    var name: String = ""
    /// "g" | "ml" | "pcs"
    var unit: String = "g"
    var aisle: String = "other"
    /// "per_100g" | "per_100ml" | "per_piece"
    var macroBasisRaw: String = "per_100g"
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fibre: Double = 0
    var cookedToDryRatio: Double? = nil
    var note: String = ""
    var labelCheck: Bool = false
    /// Excluded from shopping lists.
    var isStaple: Bool = false
    /// JSON array of {"key": String, "amount": Double} that one unit of this item expands to
    /// when shopping. Empty for normal ingredients. Used for gf_bread_slice (1/10 of the loaf).
    var shoppingExpansionJSON: String = ""

    init(
        key: String = "",
        name: String = "",
        unit: String = "g",
        aisle: String = "other",
        macroBasisRaw: String = "per_100g",
        kcal: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fibre: Double = 0,
        cookedToDryRatio: Double? = nil,
        note: String = "",
        labelCheck: Bool = false,
        isStaple: Bool = false,
        shoppingExpansionJSON: String = ""
    ) {
        self.key = key
        self.name = name
        self.unit = unit
        self.aisle = aisle
        self.macroBasisRaw = macroBasisRaw
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fibre = fibre
        self.cookedToDryRatio = cookedToDryRatio
        self.note = note
        self.labelCheck = labelCheck
        self.isStaple = isStaple
        self.shoppingExpansionJSON = shoppingExpansionJSON
    }

    var values: CatalogValues {
        CatalogValues(basis: macroBasisRaw, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fibre: fibre)
    }

    /// What one unit of this item expands to when shopping; empty for normal ingredients or bad JSON.
    var expansion: [(key: String, amount: Double)] {
        guard !shoppingExpansionJSON.isEmpty,
              let data = shoppingExpansionJSON.data(using: .utf8),
              let parts = try? JSONDecoder().decode([ExpansionPart].self, from: data)
        else { return [] }
        return parts.map { (key: $0.key, amount: $0.amount) }
    }
}

private struct ExpansionPart: Decodable {
    var key: String
    var amount: Double
}
