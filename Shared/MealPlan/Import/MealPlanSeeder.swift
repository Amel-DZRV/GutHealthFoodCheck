import Foundation
import SwiftData

/// Loads the bundled meal plan the first time the app runs, so both profiles open with their meals already in place.
@MainActor
enum MealPlanSeeder {
    /// Imports `BundledMealPlan` unless a plan is already in the store. Never overwrites existing data or edits.
    static func seedIfNeeded(_ context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let settings = try? context.fetch(FetchDescriptor<MealPlanSettings>()).first
        if settings?.importedAt != nil { return }
        let mealCount = (try? context.fetchCount(FetchDescriptor<MealDefinition>())) ?? 0
        if mealCount > 0 { return }

        guard (try? MealPlanImporter.importPlan(data: BundledMealPlan.data, into: context, now: now)) != nil else { return }

        // Start Nina's rotation this week, so today falls in week 1 rather than the week before it.
        if let settings = try? context.fetch(FetchDescriptor<MealPlanSettings>()).first {
            settings.rotationStart = sundayOnOrBefore(now, calendar: calendar)
            try? context.save()
        }
    }

    static func sundayOnOrBefore(_ date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: day) ?? day
    }
}
