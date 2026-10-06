import XCTest
@testable import GutHealthFoodCheck

final class MacrosTests: XCTestCase {
    func testEggsPerPiece() {
        let eggs = CatalogValues(basis: "per_piece", kcal: 75, protein: 6, carbs: 0.5, fat: 5, fibre: 0)
        let result = MacroMath.macros(catalog: eggs, amount: 3)
        XCTAssertEqual(result.kcal, 225, accuracy: 0.0001)
        XCTAssertEqual(result.protein, 18, accuracy: 0.0001)
    }

    func testSkyrPer100g() {
        let skyr = CatalogValues(basis: "per_100g", kcal: 63, protein: 11, carbs: 4, fat: 0.2, fibre: 0)
        let result = MacroMath.macros(catalog: skyr, amount: 100)
        XCTAssertEqual(result.kcal, 63, accuracy: 0.0001)
        XCTAssertEqual(result.protein, 11, accuracy: 0.0001)
    }

    func testPer100mlScalesByAmountOver100() {
        let milk = CatalogValues(basis: "per_100ml", kcal: 50, protein: 3, carbs: 5, fat: 2, fibre: 0)
        let result = MacroMath.macros(catalog: milk, amount: 250)
        XCTAssertEqual(result.kcal, 125, accuracy: 0.0001)
    }

    func testScalingUpFromBase() {
        let base = Macros(kcal: 225, protein: 18, carbs: 1.5, fat: 15, fibre: 0)
        let four = MacroMath.current(base: base, baseQuantity: 3, quantity: 4)
        XCTAssertEqual(four.kcal, 300, accuracy: 0.0001)
        XCTAssertEqual(four.protein, 24, accuracy: 0.0001)
    }

    func testScalingBackToBaseIsExact() {
        let base = Macros(kcal: 225, protein: 18, carbs: 1.5, fat: 15, fibre: 0)
        let three = MacroMath.current(base: base, baseQuantity: 3, quantity: 3)
        XCTAssertEqual(three, base)
        XCTAssertEqual(three.kcal, 225)
    }

    func testZeroBaseQuantityGivesZero() {
        let base = Macros(kcal: 225, protein: 18, carbs: 1.5, fat: 15, fibre: 0)
        XCTAssertEqual(MacroMath.current(base: base, baseQuantity: 0, quantity: 4), .zero)
    }

    func testAddition() {
        let a = Macros(kcal: 100, protein: 10, carbs: 5, fat: 2, fibre: 1)
        let b = Macros(kcal: 50, protein: 1, carbs: 2, fat: 3, fibre: 4)
        XCTAssertEqual(a + b, Macros(kcal: 150, protein: 11, carbs: 7, fat: 5, fibre: 5))
        XCTAssertEqual(a + .zero, a)
    }

    func testQuantityFormat() {
        XCTAssertEqual(QuantityFormat.string(1050, unit: "g"), "1.05 kg")
        XCTAssertEqual(QuantityFormat.string(1850, unit: "ml"), "1.85 L")
        XCTAssertEqual(QuantityFormat.string(200, unit: "g"), "200 g")
        XCTAssertEqual(QuantityFormat.string(1000, unit: "g"), "1 kg")
        XCTAssertEqual(QuantityFormat.string(1.5, unit: "pcs"), "1.5 pcs")
        XCTAssertEqual(QuantityFormat.string(999, unit: "ml"), "999 ml")
    }
}
