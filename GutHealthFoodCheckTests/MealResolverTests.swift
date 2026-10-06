import XCTest
@testable import GutHealthFoodCheck

final class MealResolverTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func entry(_ person: String, week: Int = 0, weekday: Int, order: Int,
                       key: String, training: String = "") -> PlanEntrySnapshot {
        PlanEntrySnapshot(person: person, weekIndex: week, weekday: weekday, order: order,
                          mealKey: key, training: training)
    }

    // MARK: Amel

    func testAmelWednesdayReturnsFourMealsInOrder() {
        // weekday 4 = Wednesday. Entries are deliberately out of order.
        let entries = [
            entry("amel", weekday: 4, order: 2, key: "amel_lunch", training: "weightlifting"),
            entry("amel", weekday: 4, order: 0, key: "amel_breakfast", training: "weightlifting"),
            entry("amel", weekday: 4, order: 3, key: "amel_dinner", training: "weightlifting"),
            entry("amel", weekday: 4, order: 1, key: "amel_snack", training: "weightlifting"),
            entry("amel", weekday: 5, order: 0, key: "amel_thursday"),
            entry("nina", weekday: 4, order: 0, key: "nina_wed"),
        ]
        // 2026-10-07 and 2026-10-14 are Wednesdays.
        for wednesday in [date(2026, 10, 7), date(2026, 10, 14)] {
            let resolved = MealResolver.resolve(person: "amel", date: wednesday, rotationStart: date(2026, 10, 11),
                                                entries: entries, overrides: [], calendar: calendar)
            XCTAssertEqual(resolved.mealKeys, ["amel_breakfast", "amel_snack", "amel_lunch", "amel_dinner"])
            XCTAssertEqual(resolved.training, "weightlifting")
            XCTAssertFalse(resolved.isOverride)
            XCTAssertEqual(resolved.date, wednesday)
        }
    }

    func testTimeOfDayIsIgnored() {
        let entries = [entry("amel", weekday: 4, order: 0, key: "amel_breakfast")]
        let evening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 21, minute: 30))!
        let resolved = MealResolver.resolve(person: "amel", date: evening, rotationStart: date(2026, 10, 11),
                                            entries: entries, overrides: [], calendar: calendar)
        XCTAssertEqual(resolved.mealKeys, ["amel_breakfast"])
        XCTAssertEqual(resolved.date, date(2026, 10, 7))
    }

    // MARK: Nina rotation

    /// Week 0 and week 1 each have a distinct meal on Sunday (1) and Saturday (7).
    private var ninaEntries: [PlanEntrySnapshot] {
        [
            entry("nina", week: 0, weekday: 1, order: 0, key: "w0_sun"),
            entry("nina", week: 1, weekday: 1, order: 0, key: "w1_sun"),
            entry("nina", week: 0, weekday: 7, order: 0, key: "w0_sat"),
            entry("nina", week: 1, weekday: 7, order: 0, key: "w1_sat"),
        ]
    }

    private func ninaKeys(_ day: Date) -> [String] {
        MealResolver.resolve(person: "nina", date: day, rotationStart: date(2026, 10, 11),
                             entries: ninaEntries, overrides: [], calendar: calendar).mealKeys
    }

    func testNinaRotationStartIsWeekZero() {
        XCTAssertEqual(ninaKeys(date(2026, 10, 11)), ["w0_sun"])
    }

    func testNinaNextWeekIsWeekOne() {
        XCTAssertEqual(ninaKeys(date(2026, 10, 18)), ["w1_sun"])
    }

    func testNinaTwoWeeksLaterIsWeekZeroAgain() {
        XCTAssertEqual(ninaKeys(date(2026, 10, 25)), ["w0_sun"])
    }

    func testNinaSaturdayBeforeStartIsWeekOne() {
        XCTAssertEqual(ninaKeys(date(2026, 10, 10)), ["w1_sat"])
    }

    func testNinaSaturdayOfFirstWeekIsWeekZero() {
        XCTAssertEqual(ninaKeys(date(2026, 10, 17)), ["w0_sat"])
    }

    func testNinaFarBeforeStartUsesFloorDivision() {
        // 14 days before the start is exactly two weeks back: week 0 again.
        XCTAssertEqual(ninaKeys(date(2026, 9, 27)), ["w0_sun"])
        // 21 days before: three weeks back, week 1.
        XCTAssertEqual(ninaKeys(date(2026, 9, 20)), ["w1_sun"])
    }

    func testNinaRotationAcrossDaylightSavingChange() {
        // Berlin switches back to winter time on 2026-10-25; the week arithmetic must not drift.
        XCTAssertEqual(ninaKeys(date(2026, 11, 1)), ["w1_sun"])
        XCTAssertEqual(ninaKeys(date(2026, 11, 8)), ["w0_sun"])
    }

    // MARK: Overrides

    func testOverrideReplacesThatDateOnly() {
        let entries = [
            entry("amel", weekday: 4, order: 0, key: "amel_wed", training: "weightlifting"),
            entry("amel", weekday: 5, order: 0, key: "amel_thu"),
        ]
        let overrides = [
            DayOverrideSnapshot(person: "amel", date: date(2026, 10, 7), mealKeys: ["custom_a", "custom_b"]),
            DayOverrideSnapshot(person: "nina", date: date(2026, 10, 8), mealKeys: ["nina_custom"]),
        ]
        let wednesday = MealResolver.resolve(person: "amel", date: date(2026, 10, 7), rotationStart: date(2026, 10, 11),
                                             entries: entries, overrides: overrides, calendar: calendar)
        XCTAssertEqual(wednesday.mealKeys, ["custom_a", "custom_b"])
        XCTAssertTrue(wednesday.isOverride)
        XCTAssertEqual(wednesday.training, "weightlifting")

        let thursday = MealResolver.resolve(person: "amel", date: date(2026, 10, 8), rotationStart: date(2026, 10, 11),
                                            entries: entries, overrides: overrides, calendar: calendar)
        XCTAssertEqual(thursday.mealKeys, ["amel_thu"])
        XCTAssertFalse(thursday.isOverride)
    }

    func testEmptyOverrideMeansNoMeals() {
        let entries = [entry("amel", weekday: 4, order: 0, key: "amel_wed")]
        let overrides = [DayOverrideSnapshot(person: "amel", date: date(2026, 10, 7), mealKeys: [])]
        let resolved = MealResolver.resolve(person: "amel", date: date(2026, 10, 7), rotationStart: date(2026, 10, 11),
                                            entries: entries, overrides: overrides, calendar: calendar)
        XCTAssertEqual(resolved.mealKeys, [])
        XCTAssertTrue(resolved.isOverride)
    }

    // MARK: Day summary

    private let target = TargetsSnapshot(kcal: 2000, proteinMin: 100, proteinMax: nil, carbs: nil, fat: nil, fibre: nil)

    func testSummaryOnlyCountsEatenKeys() {
        let meals: [(key: String, macros: Macros)] = [
            ("a", Macros(kcal: 500, protein: 30, carbs: 50, fat: 20, fibre: 5)),
            ("b", Macros(kcal: 700, protein: 40, carbs: 70, fat: 25, fibre: 8)),
            ("c", Macros(kcal: 300, protein: 10, carbs: 30, fat: 10, fibre: 2)),
        ]
        let summary = DaySummaryBuilder.build(meals: meals, eatenKeys: ["a", "c", "not_in_plan"], target: target)
        XCTAssertEqual(summary.planned.kcal, 1500, accuracy: 0.001)
        XCTAssertEqual(summary.planned.protein, 80, accuracy: 0.001)
        XCTAssertEqual(summary.eaten.kcal, 800, accuracy: 0.001)
        XCTAssertEqual(summary.eaten.protein, 40, accuracy: 0.001)
        XCTAssertEqual(summary.eaten.carbs, 80, accuracy: 0.001)
        XCTAssertEqual(summary.eaten.fat, 30, accuracy: 0.001)
        XCTAssertEqual(summary.eaten.fibre, 7, accuracy: 0.001)
        XCTAssertEqual(summary.kcalLeft, 1200, accuracy: 0.001)
    }

    func testSummaryWithNothingEatenIsZero() {
        let meals: [(key: String, macros: Macros)] = [("a", Macros(kcal: 500))]
        let summary = DaySummaryBuilder.build(meals: meals, eatenKeys: [], target: target)
        XCTAssertEqual(summary.eaten, .zero)
        XCTAssertEqual(summary.planned.kcal, 500, accuracy: 0.001)
        XCTAssertEqual(summary.kcalLeft, 2000, accuracy: 0.001)
    }

    func testKcalLeftIsNegativeWhenOverTarget() {
        let meals: [(key: String, macros: Macros)] = [
            ("a", Macros(kcal: 1500)),
            ("b", Macros(kcal: 800)),
        ]
        let summary = DaySummaryBuilder.build(meals: meals, eatenKeys: ["a", "b"], target: target)
        XCTAssertEqual(summary.eaten.kcal, 2300, accuracy: 0.001)
        XCTAssertEqual(summary.kcalLeft, -300, accuracy: 0.001)
    }
}
