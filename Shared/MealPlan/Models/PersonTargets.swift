import Foundation
import SwiftData

/// Daily targets of one person. A nil optional means "no target": show eaten only.
@Model
final class PersonTargets {
    var person: String = ""
    var kcal: Double = 0
    /// protein_g, or protein_g_min
    var proteinMin: Double = 0
    /// protein_g_max when it's a range
    var proteinMax: Double? = nil
    var carbs: Double? = nil
    var fat: Double? = nil
    var fibre: Double? = nil

    init(
        person: String = "",
        kcal: Double = 0,
        proteinMin: Double = 0,
        proteinMax: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fibre: Double? = nil
    ) {
        self.person = person
        self.kcal = kcal
        self.proteinMin = proteinMin
        self.proteinMax = proteinMax
        self.carbs = carbs
        self.fat = fat
        self.fibre = fibre
    }

    var snapshot: TargetsSnapshot {
        TargetsSnapshot(
            kcal: kcal,
            proteinMin: proteinMin,
            proteinMax: proteinMax,
            carbs: carbs,
            fat: fat,
            fibre: fibre
        )
    }
}
