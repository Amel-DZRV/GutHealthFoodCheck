import Foundation
import SwiftData

enum MealPlanImportError: LocalizedError {
    case invalidJSON(String)
    case missingMeal(String)
    case missingIngredient(meal: String, ingredient: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail):
            return "The file is not a valid meal plan: \(detail)"
        case .missingMeal(let id):
            return "The plan uses the meal \"\(id)\", but it is not defined in the meals list."
        case .missingIngredient(let meal, let ingredient):
            return "The meal \"\(meal)\" uses the ingredient \"\(ingredient)\", which is not in the ingredient list."
        }
    }
}

struct MealPlanImportSummary {
    var meals: Int
    var ingredients: Int
    var people: [String]
}

/// Replaces all meal plan data in the store with the contents of a `meal-plan.json` file.
@MainActor
enum MealPlanImporter {
    private static let breadKey = "gf_bread_slice"
    private static let stapleKeys: Set<String> = ["coffee", "salt", "sugar", "vanilla_sugar"]
    private static let weekdays = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]

    static func importPlan(data: Data, into context: ModelContext, now: Date = .now) throws -> MealPlanImportSummary {
        // 1. Decode.
        let dto: MealPlanDTO
        do {
            dto = try JSONDecoder().decode(MealPlanDTO.self, from: data)
        } catch {
            throw MealPlanImportError.invalidJSON(error.localizedDescription)
        }

        // 2. Validate everything before touching the store.
        let mealIDs = Set(dto.meals.map(\.id))
        var referenced: [String] = []
        for day in dto.plans.amel?.days ?? [] {
            guard weekdays[day.day] != nil else {
                throw MealPlanImportError.invalidJSON("Unknown day \"\(day.day)\" in Amel's plan.")
            }
            referenced += day.meals
        }
        for week in dto.plans.nina?.weeks ?? [] {
            for day in week.days {
                guard weekdays[day.day] != nil else {
                    throw MealPlanImportError.invalidJSON("Unknown day \"\(day.day)\" in Nina's plan.")
                }
                referenced += day.meals
            }
        }
        for id in referenced where !mealIDs.contains(id) {
            throw MealPlanImportError.missingMeal(id)
        }

        var ingredientKeys = Set(dto.ingredients.map(\.id))
        if dto.recipes?.gfBreadSlice != nil { ingredientKeys.insert(breadKey) }
        for meal in dto.meals {
            for item in meal.items where !ingredientKeys.contains(item.ingredient) {
                throw MealPlanImportError.missingIngredient(meal: meal.id, ingredient: item.ingredient)
            }
        }

        // 3. Delete existing data. One by one so the cascade deletes run.
        for object in try context.fetch(FetchDescriptor<CatalogIngredient>()) { context.delete(object) }
        for object in try context.fetch(FetchDescriptor<MealDefinition>()) { context.delete(object) }
        for object in try context.fetch(FetchDescriptor<PlanEntry>()) { context.delete(object) }
        for object in try context.fetch(FetchDescriptor<DayOverride>()) { context.delete(object) }
        for object in try context.fetch(FetchDescriptor<MealCompletion>()) { context.delete(object) }
        for object in try context.fetch(FetchDescriptor<PersonTargets>()) { context.delete(object) }
        for object in try context.fetch(FetchDescriptor<ShoppingListItem>()) where !object.isManual {
            context.delete(object)
        }

        // 4. Catalog.
        var catalog: [String: CatalogIngredient] = [:]
        for source in dto.ingredients {
            let ingredient = CatalogIngredient(
                key: source.id,
                name: source.name,
                unit: source.unit,
                aisle: source.aisle,
                macroBasisRaw: source.macroBasis,
                kcal: source.kcal,
                protein: source.proteinG,
                carbs: source.carbsG,
                fat: source.fatG,
                fibre: source.fibreG,
                cookedToDryRatio: source.cookedToDryRatio,
                note: source.note ?? "",
                labelCheck: source.labelCheck ?? false,
                isStaple: stapleKeys.contains(source.id)
            )
            context.insert(ingredient)
            catalog[source.id] = ingredient
        }
        if let slice = dto.recipes?.gfBreadSlice {
            let fraction = slice.perLoafFraction ?? 0.1
            let parts = (dto.recipes?.gfBreadLoaf?.perLoaf ?? [])
                .filter { catalog[$0.ingredient] != nil }
                .map { ExpansionPart(key: $0.ingredient, amount: $0.amount * fraction) }
            let expansionJSON = (try? JSONEncoder().encode(parts)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let bread = CatalogIngredient(
                key: breadKey,
                name: "Gluten-free bread (homemade slice)",
                unit: "pcs",
                aisle: "pantry",
                macroBasisRaw: "per_piece",
                kcal: slice.kcal,
                protein: slice.proteinG,
                carbs: slice.carbsG,
                fat: slice.fatG,
                fibre: slice.fibreG,
                shoppingExpansionJSON: expansionJSON
            )
            context.insert(bread)
            catalog[breadKey] = bread
        }

        // 5. Meals and their items.
        for source in dto.meals {
            let meal = MealDefinition(
                key: source.id,
                person: source.person,
                slot: source.slot,
                name: source.name,
                notes: source.notes ?? "",
                isTemplate: true
            )
            context.insert(meal)
            for (index, sourceItem) in source.items.enumerated() {
                guard let entry = catalog[sourceItem.ingredient] else {
                    throw MealPlanImportError.missingIngredient(meal: source.id, ingredient: sourceItem.ingredient)
                }
                let base = MacroMath.macros(catalog: entry.values, amount: sourceItem.amount)
                let item = MealItem(
                    order: index,
                    ingredientKey: sourceItem.ingredient,
                    name: entry.name,
                    unit: sourceItem.unit,
                    quantity: sourceItem.amount,
                    baseQuantity: sourceItem.amount,
                    baseKcal: base.kcal,
                    baseProtein: base.protein,
                    baseCarbs: base.carbs,
                    baseFat: base.fat,
                    baseFibre: base.fibre,
                    component: sourceItem.component ?? "",
                    state: sourceItem.state ?? "",
                    note: sourceItem.note ?? ""
                )
                context.insert(item)
                item.meal = meal
            }
        }

        // 6. Plan entries.
        var people: [String] = []
        if let amel = dto.plans.amel {
            people.append("amel")
            for day in amel.days {
                for (index, key) in day.meals.enumerated() {
                    context.insert(PlanEntry(
                        person: "amel",
                        weekIndex: 0,
                        weekday: weekdays[day.day] ?? 1,
                        order: index,
                        mealKey: key,
                        training: day.training ?? ""
                    ))
                }
            }
        }
        if let nina = dto.plans.nina {
            people.append("nina")
            for (weekIndex, week) in nina.weeks.enumerated() {
                for day in week.days {
                    for (index, key) in day.meals.enumerated() {
                        context.insert(PlanEntry(
                            person: "nina",
                            weekIndex: weekIndex,
                            weekday: weekdays[day.day] ?? 1,
                            order: index,
                            mealKey: key
                        ))
                    }
                }
            }
        }

        // 7. Targets.
        for person in dto.targets.keys.sorted() {
            guard let target = dto.targets[person] else { continue }
            context.insert(PersonTargets(
                person: person,
                kcal: target.kcal,
                proteinMin: target.proteinG ?? target.proteinGMin ?? 0,
                proteinMax: target.proteinGMax
            ))
        }

        // 8. Settings: keep an existing rotationStart, otherwise the next Sunday.
        let settings: MealPlanSettings
        if let existing = try context.fetch(FetchDescriptor<MealPlanSettings>()).first {
            settings = existing
        } else {
            settings = MealPlanSettings(rotationStart: firstSunday(onOrAfter: now))
            context.insert(settings)
        }
        settings.importedAt = now

        // 9. Save.
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return MealPlanImportSummary(meals: dto.meals.count, ingredients: catalog.count, people: people)
    }

    /// First Sunday on or after the start of `date`'s day.
    private static func firstSunday(onOrAfter date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (8 - weekday) % 7
        return calendar.date(byAdding: .day, value: offset, to: day) ?? day
    }
}

/// One shopping expansion line; encodes to the {"key","amount"} shape `CatalogIngredient.expansion` reads.
private struct ExpansionPart: Encodable {
    var key: String
    var amount: Double
}
