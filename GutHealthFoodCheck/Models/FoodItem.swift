import Foundation
import SwiftData

/// A food at a specific portion. "Banana 50 g" and "Banana 150 g" are separate
/// items because FODMAP tolerance usually depends on the amount eaten.
@Model
final class FoodItem {
    var name: String = ""
    var portion: Double = 0
    var unitRaw: String = "g"
    var categoryRaw: String = "mixed"
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SymptomLog.food)
    var logs: [SymptomLog] = []

    init(name: String, portion: Double, unit: PortionUnit, category: FODMAPCategory, notes: String = "") {
        self.name = name
        self.portion = portion
        self.unitRaw = unit.rawValue
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.createdAt = Date()
    }

    var category: FODMAPCategory {
        get { FODMAPCategory(rawValue: categoryRaw) ?? .mixed }
        set { categoryRaw = newValue.rawValue }
    }

    var unit: PortionUnit {
        get { PortionUnit(rawValue: unitRaw) ?? .grams }
        set { unitRaw = newValue.rawValue }
    }

    var portionLabel: String {
        "\(portion.formatted(.number.precision(.fractionLength(0...1)))) \(unit.rawValue)"
    }

    var sortedLogs: [SymptomLog] {
        logs.sorted { $0.date > $1.date }
    }

    var averageSeverity: Double? {
        guard !logs.isEmpty else { return nil }
        return logs.map(\.severity).reduce(0, +) / Double(logs.count)
    }

    var averageBloating: Double? {
        guard !logs.isEmpty else { return nil }
        return Double(logs.map(\.bloating).reduce(0, +)) / Double(logs.count)
    }

    var tolerance: Tolerance {
        Tolerance(averageSeverity: averageSeverity)
    }

    // MARK: - Duplicate detection

    /// Case-, accent- and whitespace-insensitive form of a food name.
    static func normalizedName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    func hasSameName(as otherName: String) -> Bool {
        Self.normalizedName(name) == Self.normalizedName(otherName)
    }

    func isSameFood(name otherName: String, portion otherPortion: Double, unit otherUnit: PortionUnit) -> Bool {
        hasSameName(as: otherName) && unit == otherUnit && abs(portion - otherPortion) < 0.001
    }
}
