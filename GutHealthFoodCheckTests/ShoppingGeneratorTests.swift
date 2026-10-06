import XCTest
import SwiftData
@testable import GutHealthFoodCheck

final class ShoppingGeneratorTests: XCTestCase {

    // MARK: - Helpers

    /// Hand-built catalog mirroring the real data for the cases below.
    private func catalog() -> [String: CatalogSnapshot] {
        [
            "rice": CatalogSnapshot(name: "Rice", unit: "g", aisle: "pantry", cookedToDryRatio: 2.7),
            "coffee": CatalogSnapshot(name: "Coffee", unit: "ml", aisle: "pantry", isStaple: true),
            "salt": CatalogSnapshot(name: "Salt", unit: "g", aisle: "pantry", isStaple: true),
            "sugar": CatalogSnapshot(name: "Sugar", unit: "g", aisle: "pantry", isStaple: true),
            "gf_flour": CatalogSnapshot(name: "Gluten-free flour", unit: "g", aisle: "pantry"),
            "egg": CatalogSnapshot(name: "Eggs", unit: "pcs", aisle: "dairy_eggs"),
            "milk_lf": CatalogSnapshot(name: "Milk", unit: "ml", aisle: "dairy_eggs"),
            "olive_oil": CatalogSnapshot(name: "Olive oil", unit: "g", aisle: "pantry"),
            "chicken_breast": CatalogSnapshot(name: "Chicken breast", unit: "g", aisle: "meat_fish"),
            "salmon": CatalogSnapshot(name: "salmon", unit: "g", aisle: "meat_fish"),
            "tomato": CatalogSnapshot(name: "Tomato", unit: "pcs", aisle: "produce"),
            "banana": CatalogSnapshot(name: "Banana", unit: "pcs", aisle: "produce"),
            "berries_frozen": CatalogSnapshot(name: "Frozen berries", unit: "g", aisle: "frozen"),
            "whey_protein": CatalogSnapshot(name: "Whey protein", unit: "g", aisle: "supplements"),
            "mystery": CatalogSnapshot(name: "Mystery", unit: "g", aisle: "weird_aisle"),
            "gf_bread_slice": CatalogSnapshot(
                name: "Gluten-free bread (homemade slice)", unit: "pcs", aisle: "pantry",
                expansion: [
                    (key: "gf_flour", amount: 45),
                    (key: "egg", amount: 0.2),
                    (key: "milk_lf", amount: 10),
                    (key: "olive_oil", amount: 2.3),
                    (key: "sugar", amount: 1),
                    (key: "salt", amount: 1),
                ]),
        ]
    }

    private func input(_ key: String, _ quantity: Double, _ unit: String, _ state: String = "") -> ShoppingInputItem {
        ShoppingInputItem(ingredientKey: key, quantity: quantity, unit: unit, state: state)
    }

    private func line(_ lines: [ShoppingLine], _ key: String) -> ShoppingLine? {
        lines.first { $0.key == key }
    }

    // MARK: - Rules

    func testCookedRiceBecomesDryRoundedUp() {
        let lines = ShoppingGenerator.generate(items: [input("rice", 200, "g", "cooked")], catalog: catalog())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].name, "Rice (dry)")
        XCTAssertEqual(lines[0].quantity, 75)   // 200 / 2.7 = 74.07 -> 75
        XCTAssertEqual(lines[0].unit, "g")
    }

    func testBreadSliceExpandsIntoLoafIngredients() {
        let lines = ShoppingGenerator.generate(items: [input("gf_bread_slice", 1, "pcs")], catalog: catalog())
        XCTAssertEqual(line(lines, "gf_flour")?.quantity, 45)
        XCTAssertEqual(line(lines, "gf_flour")?.unit, "g")
        XCTAssertEqual(line(lines, "egg")?.quantity, 1)   // 0.2 -> 1 pcs
        XCTAssertEqual(line(lines, "egg")?.unit, "pcs")
        XCTAssertEqual(line(lines, "milk_lf")?.quantity, 10)
        XCTAssertEqual(line(lines, "olive_oil")?.quantity, 5)   // 2.3 -> 5 g
        XCTAssertNil(line(lines, "sugar"))
        XCTAssertNil(line(lines, "salt"))
        XCTAssertNil(line(lines, "gf_bread_slice"))
    }

    func testExpansionScalesWithQuantityAndAvoidsFloatingErrorRoundUp() {
        // 5 slices: eggs 0.2 * 5 = 1.0000000000000002 must still be 1 pcs, not 2.
        let lines = ShoppingGenerator.generate(items: [input("gf_bread_slice", 5, "pcs")], catalog: catalog())
        XCTAssertEqual(line(lines, "egg")?.quantity, 1)
        XCTAssertEqual(line(lines, "gf_flour")?.quantity, 225)
    }

    func testExpansionSkipsUnknownIngredientsAndDoesNotRecurse() {
        var cat = catalog()
        cat["egg"]?.expansion = [(key: "salmon", amount: 100)]   // would loop into salmon if recursed
        cat["gf_bread_slice"]?.expansion = [(key: "water", amount: 25), (key: "egg", amount: 1)]
        let lines = ShoppingGenerator.generate(items: [input("gf_bread_slice", 2, "pcs")], catalog: cat)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].key, "egg")
        XCTAssertEqual(lines[0].quantity, 2)
    }

    func testStaplesAreExcluded() {
        let lines = ShoppingGenerator.generate(
            items: [input("coffee", 200, "ml"), input("salt", 3, "g"), input("egg", 2, "pcs")],
            catalog: catalog())
        XCTAssertEqual(lines.map(\.key), ["egg"])
    }

    func testUnknownIngredientIsSkipped() {
        let lines = ShoppingGenerator.generate(items: [input("unicorn", 10, "g"), input("egg", 1, "pcs")],
                                               catalog: catalog())
        XCTAssertEqual(lines.map(\.key), ["egg"])
    }

    func testSameKeyAndUnitAreSummed() {
        let lines = ShoppingGenerator.generate(
            items: [input("chicken_breast", 150, "g"), input("chicken_breast", 200, "g"), input("egg", 2, "pcs"),
                    input("egg", 3, "pcs")],
            catalog: catalog())
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(line(lines, "chicken_breast")?.quantity, 350)
        XCTAssertEqual(line(lines, "egg")?.quantity, 5)
    }

    func testSumIsRoundedOnceAfterSumming() {
        // 2 + 2 = 4 -> 5 g, not 5 + 5 = 10 g.
        let lines = ShoppingGenerator.generate(items: [input("chicken_breast", 2, "g"), input("chicken_breast", 2, "g")],
                                               catalog: catalog())
        XCTAssertEqual(lines.first?.quantity, 5)
    }

    func testCookedAndUncookedRiceStayDistinctLines() {
        let lines = ShoppingGenerator.generate(
            items: [input("rice", 270, "g", "cooked"), input("rice", 50, "g", "")],
            catalog: catalog())
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first { $0.name == "Rice (dry)" }?.quantity, 100)
        XCTAssertEqual(lines.first { $0.name == "Rice" }?.quantity, 50)
    }

    func testRoundingByUnit() {
        let lines = ShoppingGenerator.generate(
            items: [input("chicken_breast", 101, "g"), input("milk_lf", 250, "ml"), input("tomato", 1.2, "pcs")],
            catalog: catalog())
        XCTAssertEqual(line(lines, "chicken_breast")?.quantity, 105)
        XCTAssertEqual(line(lines, "milk_lf")?.quantity, 250)   // already a multiple of 5
        XCTAssertEqual(line(lines, "tomato")?.quantity, 2)
    }

    func testSortByAisleThenNameCaseInsensitive() {
        let lines = ShoppingGenerator.generate(
            items: [input("mystery", 10, "g"), input("whey_protein", 30, "g"), input("berries_frozen", 100, "g"),
                    input("gf_flour", 100, "g"), input("salmon", 100, "g"), input("chicken_breast", 100, "g"),
                    input("egg", 1, "pcs"), input("tomato", 1, "pcs"), input("banana", 1, "pcs")],
            catalog: catalog())
        XCTAssertEqual(lines.map(\.key), [
            "banana", "tomato",                 // produce
            "egg",                              // dairy_eggs
            "chicken_breast", "salmon",         // meat_fish ("Chicken breast" < "salmon", case-insensitive)
            "gf_flour",                         // pantry
            "berries_frozen",                   // frozen
            "whey_protein",                     // supplements
            "mystery",                          // unknown aisle last
        ])
    }

    func testAisleTitles() {
        XCTAssertEqual(ShoppingAisle.title("dairy_eggs"), "Dairy and eggs")
        XCTAssertEqual(ShoppingAisle.title("meat_fish"), "Meat and fish")
        XCTAssertEqual(ShoppingAisle.title("other"), "Other")
        XCTAssertEqual(ShoppingAisle.title("weird_aisle"), "Weird aisle")
    }

    // MARK: - Imported fixture

    @MainActor
    func testHouseholdWeekFromImportedFixture() throws {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(
            bundle.url(forResource: "meal-plan", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "meal-plan", withExtension: "json"))
        let data = try Data(contentsOf: url)

        let config = ModelConfiguration(schema: SharedStore.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SharedStore.schema, configurations: config)
        let context = container.mainContext
        _ = try MealPlanImporter.importPlan(data: data, into: context)

        let calendar = Calendar.current
        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<MealPlanSettings>()).first)
        let start = calendar.startOfDay(for: settings.rotationStart)   // a Sunday: covers mon...sun and Nina's week 1
        XCTAssertEqual(calendar.component(.weekday, from: start), 1)

        let entries = try context.fetch(FetchDescriptor<PlanEntry>())
        let meals = try context.fetch(FetchDescriptor<MealDefinition>())
        let ingredients = try context.fetch(FetchDescriptor<CatalogIngredient>())

        var catalog: [String: CatalogSnapshot] = [:]
        for ingredient in ingredients {
            catalog[ingredient.key] = CatalogSnapshot(
                name: ingredient.name, unit: ingredient.unit, aisle: ingredient.aisle,
                cookedToDryRatio: ingredient.cookedToDryRatio, isStaple: ingredient.isStaple,
                expansion: ingredient.expansion)
        }

        var inputs: [ShoppingInputItem] = []
        for offset in 0..<7 {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start))
            for person in ["amel", "nina"] {
                let resolved = MealResolver.resolve(
                    person: person, date: day, rotationStart: start,
                    entries: entries.filter { $0.person == person }.map { $0.snapshot },
                    overrides: [])
                XCTAssertFalse(resolved.mealKeys.isEmpty, "\(person) has no meals on offset \(offset)")
                for key in resolved.mealKeys {
                    guard let meal = meals.first(where: { $0.key == key }) else { continue }
                    for item in meal.items {
                        inputs.append(ShoppingInputItem(
                            ingredientKey: item.ingredientKey, quantity: item.quantity,
                            unit: item.unit, state: item.state))
                    }
                }
            }
        }

        let lines = ShoppingGenerator.generate(items: inputs, catalog: catalog)
        let eggs = try XCTUnwrap(line(lines, "egg"))
        XCTAssertEqual(eggs.unit, "pcs")
        XCTAssertGreaterThanOrEqual(eggs.quantity, 45)   // expected 50
        XCTAssertLessThanOrEqual(eggs.quantity, 55)
        let chicken = try XCTUnwrap(line(lines, "chicken_breast"))
        XCTAssertEqual(chicken.unit, "g")
        XCTAssertGreaterThanOrEqual(chicken.quantity, 2200)   // expected 2300
        XCTAssertLessThanOrEqual(chicken.quantity, 2400)

        // Staples never appear, and the bread slice itself is replaced by its loaf ingredients.
        for key in ["coffee", "salt", "sugar", "vanilla_sugar", "gf_bread_slice"] {
            XCTAssertNil(line(lines, key), "\(key) should not be on the list")
        }
        withExtendedLifetime(container) {}
    }
}
