import Foundation

enum MealSlot {
    static let all: [String] = ["breakfast", "lunch", "pre_workout", "dinner", "snack"]

    /// "pre_workout" → "Pre-workout"; unknown slots are capitalised with underscores as spaces.
    static func title(_ slot: String) -> String {
        switch slot {
        case "breakfast": return "Breakfast"
        case "lunch": return "Lunch"
        case "pre_workout": return "Pre-workout"
        case "dinner": return "Dinner"
        case "snack": return "Snack"
        default:
            let text = slot.replacingOccurrences(of: "_", with: " ")
            return String(text.prefix(1)).uppercased() + String(text.dropFirst())
        }
    }
}
