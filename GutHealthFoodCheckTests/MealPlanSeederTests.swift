import XCTest
import SwiftData
@testable import GutHealthFoodCheck

@MainActor
final class MealPlanSeederTests: XCTestCase {
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(schema: SharedStore.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SharedStore.schema, configurations: config)
        self.container = container
        return container.mainContext
    }

    func testSeedsBundledPlanOnEmptyStore() throws {
        let context = try makeContext()
        MealPlanSeeder.seedIfNeeded(context)

        let meals = try context.fetch(FetchDescriptor<MealDefinition>())
        XCTAssertEqual(meals.count, 23)
        let dinner = try XCTUnwrap(meals.first { $0.key == "amel_dinner" })
        XCTAssertEqual(dinner.macros.kcal, 316, accuracy: 2)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<MealPlanSettings>()).first)
        XCTAssertNotNil(settings.importedAt)
        XCTAssertEqual(Calendar.current.component(.weekday, from: settings.rotationStart), 1)
        XCTAssertLessThanOrEqual(settings.rotationStart, Date.now)
    }

    func testSecondSeedLeavesEditsAlone() throws {
        let context = try makeContext()
        MealPlanSeeder.seedIfNeeded(context)
        let dinner = try XCTUnwrap(try context.fetch(FetchDescriptor<MealDefinition>()).first { $0.key == "amel_dinner" })
        dinner.name = "Edited"
        try context.save()

        MealPlanSeeder.seedIfNeeded(context)

        let meals = try context.fetch(FetchDescriptor<MealDefinition>())
        XCTAssertEqual(meals.count, 23)
        XCTAssertEqual(meals.first { $0.key == "amel_dinner" }?.name, "Edited")
    }

    func testSundayOnOrBefore() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 15))!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))!
        XCTAssertEqual(MealPlanSeeder.sundayOnOrBefore(tuesday, calendar: calendar), sunday)
        XCTAssertEqual(MealPlanSeeder.sundayOnOrBefore(sunday, calendar: calendar), sunday)
    }
}
