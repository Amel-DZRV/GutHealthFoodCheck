import Foundation
import SwiftData

/// One cooking instruction of a meal.
@Model
final class MealStep {
    var order: Int = 0
    var text: String = ""
    /// Checkmark while cooking; cleared with "Uncheck all".
    var isDone: Bool = false
    var meal: MealDefinition?

    init(order: Int = 0, text: String = "", isDone: Bool = false) {
        self.order = order
        self.text = text
        self.isDone = isDone
    }
}
