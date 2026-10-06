import Foundation

/// Plain copy of a `PersonTargets`.
struct TargetsSnapshot: Equatable {
    var kcal: Double
    var proteinMin: Double
    var proteinMax: Double?
    var carbs: Double?
    var fat: Double?
    var fibre: Double?
}

struct DaySummary: Equatable {
    var target: TargetsSnapshot
    var eaten: Macros
    var planned: Macros
    /// Negative = over target.
    var kcalLeft: Double { target.kcal - eaten.kcal }
}

enum DaySummaryBuilder {
    /// `planned` sums every meal; `eaten` sums the meals whose key is in `eatenKeys`.
    static func build(meals: [(key: String, macros: Macros)], eatenKeys: Set<String>, target: TargetsSnapshot) -> DaySummary {
        var planned = Macros.zero
        var eaten = Macros.zero
        for meal in meals {
            planned = planned + meal.macros
            if eatenKeys.contains(meal.key) {
                eaten = eaten + meal.macros
            }
        }
        return DaySummary(target: target, eaten: eaten, planned: planned)
    }
}
