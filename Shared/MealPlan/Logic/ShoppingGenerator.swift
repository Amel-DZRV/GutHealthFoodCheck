import Foundation

/// One generated shopping list line (quantities already rounded up for buying).
struct ShoppingLine: Equatable {
    var key: String
    var name: String
    var quantity: Double
    var unit: String
    var aisle: String
}

/// One ingredient amount eaten in the shopping range, copied from a `MealItem`.
struct ShoppingInputItem {
    var ingredientKey: String
    var quantity: Double
    var unit: String
    var state: String
}

/// Plain copy of the catalog fields shopping needs, so the logic doesn't depend on SwiftData.
struct CatalogSnapshot {
    var name: String
    var unit: String
    var aisle: String
    var cookedToDryRatio: Double?
    var isStaple: Bool
    /// What one unit of this item expands to when shopping (e.g. a bread slice into loaf ingredients).
    var expansion: [(key: String, amount: Double)]

    init(name: String, unit: String, aisle: String, cookedToDryRatio: Double? = nil,
         isStaple: Bool = false, expansion: [(key: String, amount: Double)] = []) {
        self.name = name
        self.unit = unit
        self.aisle = aisle
        self.cookedToDryRatio = cookedToDryRatio
        self.isStaple = isStaple
        self.expansion = expansion
    }
}

/// Aisle ordering and display titles for the shopping list.
enum ShoppingAisle {
    static let order: [String] = ["produce", "dairy_eggs", "meat_fish", "pantry", "frozen", "supplements"]

    static func title(_ aisle: String) -> String {
        switch aisle {
        case "produce": return "Produce"
        case "dairy_eggs": return "Dairy and eggs"
        case "meat_fish": return "Meat and fish"
        case "pantry": return "Pantry"
        case "frozen": return "Frozen"
        case "supplements": return "Supplements"
        default:
            let text = aisle.replacingOccurrences(of: "_", with: " ")
            guard let first = text.first else { return "Other" }
            return String(first).uppercased() + String(text.dropFirst())
        }
    }

    /// Sort position of an aisle; unknown aisles come after all known ones.
    static func rank(_ aisle: String) -> Int {
        order.firstIndex(of: aisle) ?? order.count
    }
}

enum ShoppingGenerator {
    /// Turns everything eaten in a date range into a rounded, sorted shopping list.
    ///
    /// Rules, applied in order to each input item:
    /// 1. An item whose catalog entry has an `expansion` is replaced by one input per expansion entry
    ///    (`amount × quantity`, in that ingredient's catalog unit, empty state). Each expanded ingredient
    ///    is looked up in the catalog itself and skipped if unknown. Expansion is one level only: an
    ///    expanded ingredient's own `expansion` is ignored. Expanded inputs then continue with rule 2.
    /// 2. Staples are skipped (this also drops staples that arrive through an expansion).
    /// 3. `state == "cooked"` with a `cookedToDryRatio` becomes `quantity / ratio` on a line named
    ///    "<name> (dry)".
    /// 4. Quantities are summed by key + unit + dry flag. The dry flag keeps dry and non-dry lines of the
    ///    same ingredient apart, since they are bought as different things (they share `key`, differ in
    ///    `name`).
    /// 5. Rounding up: `g` and `ml` to the next multiple of 5, `pcs` to the next whole number (with a
    ///    small epsilon so floating error like 1.0000000000000002 doesn't round up). Other units are
    ///    left as they are.
    /// 6. Sorted by aisle (`ShoppingAisle.order`, unknown aisles last), then name (case-insensitive).
    ///
    /// Input items whose ingredient is not in the catalog are skipped, as are lines that sum to zero.
    static func generate(items: [ShoppingInputItem], catalog: [String: CatalogSnapshot]) -> [ShoppingLine] {
        var sums: [String: Accumulator] = [:]

        func add(key: String, quantity: Double, unit: String, state: String) {
            guard let entry = catalog[key], !entry.isStaple else { return }   // rule 2
            var amount = quantity
            var name = entry.name
            var isDry = false
            if state == "cooked", let ratio = entry.cookedToDryRatio, ratio > 0 {   // rule 3
                amount = quantity / ratio
                name = "\(entry.name) (dry)"
                isDry = true
            }
            let sumKey = "\(key)|\(unit)|\(isDry)"   // rule 4
            if var existing = sums[sumKey] {
                existing.quantity += amount
                sums[sumKey] = existing
            } else {
                sums[sumKey] = Accumulator(key: key, name: name, quantity: amount, unit: unit, aisle: entry.aisle)
            }
        }

        for item in items {
            guard let entry = catalog[item.ingredientKey] else { continue }
            if entry.expansion.isEmpty {
                add(key: item.ingredientKey, quantity: item.quantity, unit: item.unit, state: item.state)
            } else {   // rule 1
                for part in entry.expansion {
                    guard let partEntry = catalog[part.key] else { continue }
                    add(key: part.key, quantity: part.amount * item.quantity, unit: partEntry.unit, state: "")
                }
            }
        }

        let lines = sums.values
            .filter { $0.quantity > epsilon }
            .map { acc in
                ShoppingLine(key: acc.key, name: acc.name, quantity: roundUp(acc.quantity, unit: acc.unit),
                             unit: acc.unit, aisle: acc.aisle)
            }
        return lines.sorted(by: lineOrder)   // rule 6
    }

    private struct Accumulator {
        var key: String
        var name: String
        var quantity: Double
        var unit: String
        var aisle: String
    }

    private static let epsilon = 1e-9

    /// Rule 5. Never rounds a positive amount down to zero.
    private static func roundUp(_ quantity: Double, unit: String) -> Double {
        let step: Double
        switch unit {
        case "g", "ml": step = 5
        case "pcs": step = 1
        default: return quantity
        }
        return max(step, ceil(quantity / step - epsilon) * step)
    }

    private static func lineOrder(_ a: ShoppingLine, _ b: ShoppingLine) -> Bool {
        let ra = ShoppingAisle.rank(a.aisle), rb = ShoppingAisle.rank(b.aisle)
        if ra != rb { return ra < rb }
        if a.aisle != b.aisle { return a.aisle < b.aisle }   // two different unknown aisles
        let byName = a.name.localizedCaseInsensitiveCompare(b.name)
        if byName != .orderedSame { return byName == .orderedAscending }
        if a.key != b.key { return a.key < b.key }
        return a.unit < b.unit
    }
}
