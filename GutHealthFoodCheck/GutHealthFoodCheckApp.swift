import SwiftData
import SwiftUI

@main
struct GutHealthFoodCheckApp: App {
    var body: some Scene {
        WindowGroup {
            FoodListView()
        }
        .modelContainer(for: [FoodItem.self, SymptomLog.self])
    }
}
