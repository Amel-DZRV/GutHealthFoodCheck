import XCTest
import SwiftData
@testable import GutHealthFoodCheck

@MainActor
final class ImporterTests: XCTestCase {
    private var container: ModelContainer?

    // MARK: Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(schema: SharedStore.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SharedStore.schema, configurations: config)
        self.container = container
        return container.mainContext
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(
            bundle.url(forResource: "meal-plan", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "meal-plan", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func fixtureObject() throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
    }

    private func data(from object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func count<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    private func meal(_ key: String, _ context: ModelContext) throws -> MealDefinition {
        try XCTUnwrap(try context.fetch(FetchDescriptor<MealDefinition>()).first { $0.key == key })
    }

    // MARK: Successful import

    func testImportSucceedsWithExpectedCounts() throws {
        let context = try makeContext()
        let json = try fixtureObject()
        let summary = try MealPlanImporter.importPlan(data: try fixtureData(), into: context)

        let jsonMeals = try XCTUnwrap(json["meals"] as? [[String: Any]])
        let jsonIngredients = try XCTUnwrap(json["ingredients"] as? [[String: Any]])
        XCTAssertEqual(jsonMeals.count, 23)
        XCTAssertEqual(summary.meals, 23)
        XCTAssertEqual(summary.ingredients, jsonIngredients.count + 1)
        XCTAssertEqual(summary.people, ["amel", "nina"])
        XCTAssertEqual(try count(MealDefinition.self, context), 23)
        XCTAssertEqual(try count(CatalogIngredient.self, context), jsonIngredients.count + 1)
        XCTAssertEqual(try count(PersonTargets.self, context), 2)
        XCTAssertEqual(try count(MealStep.self, context), 0)
    }

    func testNinaPlanEntriesCoverFourteenDays() throws {
        let context = try makeContext()
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context)

        // A PlanEntry is one meal slot, so expect one entry per meal id across Nina's 14 days.
        let json = try fixtureObject()
        let plans = try XCTUnwrap(json["plans"] as? [String: Any])
        let nina = try XCTUnwrap(plans["nina"] as? [String: Any])
        let weeks = try XCTUnwrap(nina["weeks"] as? [[String: Any]])
        XCTAssertEqual(weeks.count, 2)
        var expectedEntries = 0
        for week in weeks {
            let days = try XCTUnwrap(week["days"] as? [[String: Any]])
            XCTAssertEqual(days.count, 7)
            for day in days {
                expectedEntries += (try XCTUnwrap(day["meals"] as? [String])).count
            }
        }

        let entries = try context.fetch(FetchDescriptor<PlanEntry>()).filter { $0.person == "nina" }
        XCTAssertEqual(entries.count, expectedEntries)
        XCTAssertEqual(entries.count, 70)
        struct DayKey: Hashable { var week: Int; var weekday: Int }
        let distinctDays = Set(entries.map { DayKey(week: $0.weekIndex, weekday: $0.weekday) })
        XCTAssertEqual(distinctDays.count, 14)
        XCTAssertEqual(Set(entries.map(\.weekIndex)), [0, 1])
        XCTAssertEqual(Set(entries.map(\.weekday)), Set(1...7))
    }

    func testAmelDinnerMacros() throws {
        let context = try makeContext()
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context)

        let macros = try meal("amel_dinner", context).macros
        XCTAssertEqual(macros.kcal, 316, accuracy: 2)
        XCTAssertEqual(macros.protein, 37.7, accuracy: 0.5)
    }

    func testAmelMondayEntriesSumToPlannedKcal() throws {
        let context = try makeContext()
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context)

        let entries = try context.fetch(FetchDescriptor<PlanEntry>())
            .filter { $0.person == "amel" && $0.weekday == 2 }
            .sorted { $0.order < $1.order }
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(Set(entries.map(\.weekIndex)), [0])
        XCTAssertEqual(entries.first?.training, "weightlifting")

        var total = Macros.zero
        for entry in entries {
            let mealMacros = try meal(entry.mealKey, context).macros
            total = total + mealMacros
        }
        XCTAssertEqual(total.kcal, 2169, accuracy: 5)
    }

    func testBreadStaplesTargetsAndItems() throws {
        let context = try makeContext()
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context)
        let ingredients = try context.fetch(FetchDescriptor<CatalogIngredient>())

        let bread = try XCTUnwrap(ingredients.first { $0.key == "gf_bread_slice" })
        XCTAssertEqual(bread.name, "Gluten-free bread (homemade slice)")
        XCTAssertEqual(bread.unit, "pcs")
        XCTAssertEqual(bread.aisle, "pantry")
        XCTAssertEqual(bread.macroBasisRaw, "per_piece")
        XCTAssertEqual(bread.kcal, 200.3, accuracy: 0.01)
        let expansion = bread.expansion
        XCTAssertFalse(expansion.isEmpty)
        XCTAssertNil(expansion.first { $0.key == "water" })
        let egg = try XCTUnwrap(expansion.first { $0.key == "egg" })
        XCTAssertEqual(egg.amount, 0.2, accuracy: 0.0001)
        let flour = try XCTUnwrap(expansion.first { $0.key == "gf_flour" })
        XCTAssertEqual(flour.amount, 45, accuracy: 0.0001)

        for key in ["coffee", "salt", "sugar", "vanilla_sugar"] {
            XCTAssertEqual(ingredients.first { $0.key == key }?.isStaple, true, key)
        }
        XCTAssertEqual(ingredients.first { $0.key == "egg" }?.isStaple, false)

        let targets = try context.fetch(FetchDescriptor<PersonTargets>())
        let amel = try XCTUnwrap(targets.first { $0.person == "amel" })
        XCTAssertEqual(amel.kcal, 2250)
        XCTAssertEqual(amel.proteinMin, 200)
        XCTAssertNil(amel.proteinMax)
        let nina = try XCTUnwrap(targets.first { $0.person == "nina" })
        XCTAssertEqual(nina.kcal, 2000)
        XCTAssertEqual(nina.proteinMin, 130)
        XCTAssertEqual(nina.proteinMax, 150)

        let breakfast = try meal("amel_breakfast", context)
        let breadItem = try XCTUnwrap(breakfast.sortedItems.first { $0.ingredientKey == "gf_bread_slice" })
        XCTAssertEqual(breadItem.name, "Gluten-free bread (homemade slice)")
        XCTAssertEqual(breadItem.quantity, 1)
        XCTAssertEqual(breadItem.baseQuantity, 1)
        XCTAssertEqual(breadItem.baseKcal, 200.3, accuracy: 0.01)
        XCTAssertEqual(breakfast.sortedItems.map(\.order), Array(0..<breakfast.items.count))
        XCTAssertTrue(breakfast.isTemplate)
    }

    func testSettingsRotationStartIsSundayAndKeptOnReimport() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let now = Date()
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context, now: now)

        var settings = try XCTUnwrap(try context.fetch(FetchDescriptor<MealPlanSettings>()).first)
        XCTAssertEqual(calendar.component(.weekday, from: settings.rotationStart), 1)
        XCTAssertGreaterThanOrEqual(settings.rotationStart, calendar.startOfDay(for: now))
        XCTAssertLessThan(settings.rotationStart, calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!)
        XCTAssertEqual(settings.importedAt, now)
        let firstRotation = settings.rotationStart

        let later = calendar.date(byAdding: .day, value: 20, to: now)!
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context, now: later)
        XCTAssertEqual(try count(MealPlanSettings.self, context), 1)
        settings = try XCTUnwrap(try context.fetch(FetchDescriptor<MealPlanSettings>()).first)
        XCTAssertEqual(settings.rotationStart, firstRotation)
        XCTAssertEqual(settings.importedAt, later)
    }

    // MARK: Re-import

    func testImportingTwiceDoesNotDuplicate() throws {
        let context = try makeContext()
        let json = try fixtureObject()
        let jsonIngredients = try XCTUnwrap(json["ingredients"] as? [[String: Any]])
        let data = try fixtureData()

        _ = try MealPlanImporter.importPlan(data: data, into: context)
        let first = try counts(context)
        _ = try MealPlanImporter.importPlan(data: data, into: context)
        let second = try counts(context)

        XCTAssertEqual(first, second)
        XCTAssertEqual(second.catalog, jsonIngredients.count + 1)
        XCTAssertEqual(second.meals, 23)
        XCTAssertEqual(second.targets, 2)
        XCTAssertEqual(second.settings, 1)
        // 4 meals x 7 days for Amel + 70 for Nina; items are only deleted via cascade.
        XCTAssertEqual(second.entries, 28 + 70)
        let allItems = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(allItems.count, first.items)
        XCTAssertTrue(allItems.allSatisfy { $0.meal != nil })
    }

    private struct Counts: Equatable {
        var catalog: Int, meals: Int, items: Int, entries: Int, targets: Int, settings: Int
    }

    private func counts(_ context: ModelContext) throws -> Counts {
        Counts(
            catalog: try count(CatalogIngredient.self, context),
            meals: try count(MealDefinition.self, context),
            items: try count(MealItem.self, context),
            entries: try count(PlanEntry.self, context),
            targets: try count(PersonTargets.self, context),
            settings: try count(MealPlanSettings.self, context)
        )
    }

    func testReimportClearsUserDataButKeepsManualShoppingItems() throws {
        let context = try makeContext()
        let data = try fixtureData()
        _ = try MealPlanImporter.importPlan(data: data, into: context)

        context.insert(ShoppingListItem(name: "Generated", quantity: 1, unit: "pcs", isManual: false, sourceKey: "egg"))
        context.insert(ShoppingListItem(name: "Batteries", quantity: 2, unit: "pcs", isManual: true))
        context.insert(DayOverride(person: "amel", date: Calendar.current.startOfDay(for: Date()), mealKeys: ["amel_dinner"]))
        context.insert(MealCompletion(person: "amel", date: Calendar.current.startOfDay(for: Date()), mealKey: "amel_dinner"))
        let copy = MealDefinition(key: "amel_dinner@2026-10-07", person: "amel", slot: "dinner", name: "Copy", isTemplate: false)
        context.insert(copy)
        try context.save()

        _ = try MealPlanImporter.importPlan(data: data, into: context)

        let shopping = try context.fetch(FetchDescriptor<ShoppingListItem>())
        XCTAssertEqual(shopping.map(\.name), ["Batteries"])
        XCTAssertEqual(try count(DayOverride.self, context), 0)
        XCTAssertEqual(try count(MealCompletion.self, context), 0)
        XCTAssertEqual(try count(MealDefinition.self, context), 23)
    }

    // MARK: Errors

    func testUnknownIngredientThrowsMissingIngredient() throws {
        let context = try makeContext()
        var json = try fixtureObject()
        var meals = try XCTUnwrap(json["meals"] as? [[String: Any]])
        var first = meals[0]
        var items = try XCTUnwrap(first["items"] as? [[String: Any]])
        items[0]["ingredient"] = "unobtainium"
        first["items"] = items
        meals[0] = first
        json["meals"] = meals
        let mealID = try XCTUnwrap(first["id"] as? String)

        XCTAssertThrowsError(try MealPlanImporter.importPlan(data: try data(from: json), into: context)) { error in
            guard case MealPlanImportError.missingIngredient(let meal, let ingredient) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(meal, mealID)
            XCTAssertEqual(ingredient, "unobtainium")
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        XCTAssertEqual(try count(MealDefinition.self, context), 0)
    }

    func testUnknownMealInPlanThrowsMissingMeal() throws {
        let context = try makeContext()
        var json = try fixtureObject()
        var plans = try XCTUnwrap(json["plans"] as? [String: Any])
        var amel = try XCTUnwrap(plans["amel"] as? [String: Any])
        var days = try XCTUnwrap(amel["days"] as? [[String: Any]])
        var meals = try XCTUnwrap(days[0]["meals"] as? [String])
        meals.append("ghost_meal")
        days[0]["meals"] = meals
        amel["days"] = days
        plans["amel"] = amel
        json["plans"] = plans

        XCTAssertThrowsError(try MealPlanImporter.importPlan(data: try data(from: json), into: context)) { error in
            guard case MealPlanImportError.missingMeal(let id) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(id, "ghost_meal")
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testInvalidJSONThrowsInvalidJSON() throws {
        let context = try makeContext()
        XCTAssertThrowsError(try MealPlanImporter.importPlan(data: Data("not json".utf8), into: context)) { error in
            guard case MealPlanImportError.invalidJSON = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testFailedImportLeavesExistingDataUntouched() throws {
        let context = try makeContext()
        _ = try MealPlanImporter.importPlan(data: try fixtureData(), into: context)
        context.insert(ShoppingListItem(name: "Generated", isManual: false))
        try context.save()
        let before = try counts(context)
        let shoppingBefore = try count(ShoppingListItem.self, context)

        var json = try fixtureObject()
        var meals = try XCTUnwrap(json["meals"] as? [[String: Any]])
        var items = try XCTUnwrap(meals[0]["items"] as? [[String: Any]])
        items[0]["ingredient"] = "unobtainium"
        meals[0]["items"] = items
        json["meals"] = meals

        XCTAssertThrowsError(try MealPlanImporter.importPlan(data: try data(from: json), into: context))
        XCTAssertThrowsError(try MealPlanImporter.importPlan(data: Data("{}".utf8), into: context))

        XCTAssertEqual(try counts(context), before)
        XCTAssertEqual(try count(ShoppingListItem.self, context), shoppingBefore)
        XCTAssertEqual(try meal("amel_dinner", context).macros.kcal, 316, accuracy: 2)
    }

    func testToleratesMissingOptionalFields() throws {
        let context = try makeContext()
        var json = try fixtureObject()
        json["unknown_top_level_key"] = ["anything": 1]
        var plans = try XCTUnwrap(json["plans"] as? [String: Any])
        var amel = try XCTUnwrap(plans["amel"] as? [String: Any])
        var days = try XCTUnwrap(amel["days"] as? [[String: Any]])
        for index in days.indices { days[index].removeValue(forKey: "training") }
        amel["days"] = days
        plans["amel"] = amel
        json["plans"] = plans

        _ = try MealPlanImporter.importPlan(data: try data(from: json), into: context)
        let entries = try context.fetch(FetchDescriptor<PlanEntry>()).filter { $0.person == "amel" }
        XCTAssertEqual(entries.count, 28)
        XCTAssertTrue(entries.allSatisfy { $0.training.isEmpty })
    }
}
