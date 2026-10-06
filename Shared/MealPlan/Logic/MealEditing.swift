import Foundation
import SwiftData

/// Copy-on-write editing of a day's meals: edits never touch the shared template.
@MainActor
enum MealEditing {
    /// The meal to edit for this date. Templates are deep-copied under "<key>@yyyy-MM-dd"
    /// and the copy replaces the template in the day's override; copies are returned as they are.
    static func editableMeal(key: String, person: String, date: Date, context: ModelContext) -> MealDefinition {
        let day = Calendar.current.startOfDay(for: date)
        let dayKey = dayString(day)

        let source = fetchMeal(key: key, context: context)
        if let source, !source.isTemplate { return source }

        let dayOverride = ensureOverride(person: person, date: day, context: context)
        let copyKey = "\(key)@\(dayKey)"

        // Re-editing the same day: reuse the copy made earlier.
        let copy: MealDefinition
        if let existing = fetchMeal(key: copyKey, context: context) {
            copy = existing
        } else {
            copy = MealDefinition(
                key: copyKey,
                person: source?.person ?? person,
                slot: source?.slot ?? "",
                name: source?.name ?? "",
                notes: source?.notes ?? "",
                isTemplate: false
            )
            context.insert(copy)
            if let source {
                for item in source.sortedItems {
                    let itemCopy = MealItem(
                        order: item.order,
                        ingredientKey: item.ingredientKey,
                        name: item.name,
                        unit: item.unit,
                        quantity: item.quantity,
                        baseQuantity: item.baseQuantity,
                        baseKcal: item.baseKcal,
                        baseProtein: item.baseProtein,
                        baseCarbs: item.baseCarbs,
                        baseFat: item.baseFat,
                        baseFibre: item.baseFibre,
                        component: item.component,
                        state: item.state,
                        note: item.note
                    )
                    context.insert(itemCopy)
                    itemCopy.meal = copy
                }
                for step in source.sortedSteps {
                    let stepCopy = MealStep(order: step.order, text: step.text, isDone: step.isDone)
                    context.insert(stepCopy)
                    stepCopy.meal = copy
                }
            }
        }

        dayOverride.mealKeys = dayOverride.mealKeys.map { $0 == key ? copyKey : $0 }

        for completion in completions(person: person, date: day, key: key, context: context) {
            completion.mealKey = copyKey
        }

        try? context.save()
        return copy
    }

    /// Adds a new empty custom meal to the day and returns it.
    static func addMeal(person: String, date: Date, slot: String, name: String, context: ModelContext) -> MealDefinition {
        let day = Calendar.current.startOfDay(for: date)
        let dayOverride = ensureOverride(person: person, date: day, context: context)

        let meal = MealDefinition(
            key: "custom-\(UUID().uuidString)@\(dayString(day))",
            person: person,
            slot: slot,
            name: name,
            isTemplate: false
        )
        context.insert(meal)
        dayOverride.mealKeys.append(meal.key)

        try? context.save()
        return meal
    }

    /// Removes a meal from this day only. Templates stay; copies and custom meals of the day are deleted.
    static func removeMeal(key: String, person: String, date: Date, context: ModelContext) {
        let day = Calendar.current.startOfDay(for: date)
        let dayOverride = ensureOverride(person: person, date: day, context: context)
        dayOverride.mealKeys.removeAll { $0 == key }

        for completion in completions(person: person, date: day, key: key, context: context) {
            context.delete(completion)
        }

        if let meal = fetchMeal(key: key, context: context), !meal.isTemplate {
            context.delete(meal)
        }

        try? context.save()
    }

    // MARK: - Helpers

    /// "yyyy-MM-dd" in the current calendar, independent of locale.
    private static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func fetchMeal(key: String, context: ModelContext) -> MealDefinition? {
        let descriptor = FetchDescriptor<MealDefinition>(predicate: #Predicate<MealDefinition> { $0.key == key })
        return (try? context.fetch(descriptor))?.first
    }

    private static func completions(person: String, date: Date, key: String, context: ModelContext) -> [MealCompletion] {
        let descriptor = FetchDescriptor<MealCompletion>(
            predicate: #Predicate<MealCompletion> { $0.person == person && $0.mealKey == key }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { Calendar.current.startOfDay(for: $0.date) == date }
    }

    /// The day's override; created from the currently resolved meal keys when missing.
    private static func ensureOverride(person: String, date: Date, context: ModelContext) -> DayOverride {
        let overrides = (try? context.fetch(FetchDescriptor<DayOverride>())) ?? []
        if let existing = overrides.first(where: {
            $0.person == person && Calendar.current.startOfDay(for: $0.date) == date
        }) {
            return existing
        }

        let entries = (try? context.fetch(FetchDescriptor<PlanEntry>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<MealPlanSettings>()))?.first
        let resolved = MealResolver.resolve(
            person: person,
            date: date,
            rotationStart: settings?.rotationStart ?? date,
            entries: entries.filter { $0.person == person }.map(\.snapshot),
            overrides: overrides.filter { $0.person == person }.map(\.snapshot)
        )

        let dayOverride = DayOverride(person: person, date: date, mealKeys: resolved.mealKeys)
        context.insert(dayOverride)
        return dayOverride
    }
}
