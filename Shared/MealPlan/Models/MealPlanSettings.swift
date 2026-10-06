import Foundation
import SwiftData

/// The single settings record for the meal plan.
@Model
final class MealPlanSettings {
    var importedAt: Date? = nil
    /// A Sunday; Nina's week 1 begins here.
    var rotationStart: Date = Date()
    var shoppingStart: Date = Date()
    var shoppingDays: Int = 7
    var shoppingHousehold: Bool = true

    init(
        importedAt: Date? = nil,
        rotationStart: Date = Date(),
        shoppingStart: Date = Date(),
        shoppingDays: Int = 7,
        shoppingHousehold: Bool = true
    ) {
        self.importedAt = importedAt
        self.rotationStart = rotationStart
        self.shoppingStart = shoppingStart
        self.shoppingDays = shoppingDays
        self.shoppingHousehold = shoppingHousehold
    }
}
