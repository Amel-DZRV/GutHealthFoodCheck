import SwiftUI

/// Calories left / eaten / planned for a day, with the macro targets below.
struct DaySummaryCard: View {
    let summary: DaySummary

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                leftColumn
                column(title: "Eaten", value: Self.format(summary.eaten.kcal))
                column(title: "Total", value: Self.format(summary.planned.kcal))
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    macro("Protein", eaten: summary.eaten.protein, target: summary.target.proteinMin, max: summary.target.proteinMax)
                    macro("Carbs", eaten: summary.eaten.carbs, target: summary.target.carbs)
                }
                GridRow {
                    macro("Fat", eaten: summary.eaten.fat, target: summary.target.fat)
                    macro("Fibre", eaten: summary.eaten.fibre, target: summary.target.fibre)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var leftColumn: some View {
        let left = summary.kcalLeft
        if left < 0 {
            column(title: "Left", value: "+\(Self.format(-left)) over", color: .orange)
        } else {
            column(title: "Left", value: Self.format(left))
        }
    }

    private func column(title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("\(title) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func macro(_ title: String, eaten: Double, target: Double?, max: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.macroText(eaten: eaten, target: target, max: max))
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "eaten / target g", "eaten / min–max g" for a range, or "eaten g" without a target.
    private static func macroText(eaten: Double, target: Double?, max: Double?) -> String {
        guard let target else { return "\(grams(eaten)) g" }
        if let max {
            return "\(grams(eaten)) / \(grams(target))–\(grams(max)) g"
        }
        return "\(grams(eaten)) / \(grams(target)) g"
    }

    private static func format(_ kcal: Double) -> String {
        kcal.formatted(.number.precision(.fractionLength(0)))
    }

    private static func grams(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview {
    let target = TargetsSnapshot(kcal: 2200, proteinMin: 130, proteinMax: 150, carbs: nil, fat: 70, fibre: nil)
    let eaten = Macros(kcal: 1250, protein: 82.5, carbs: 140, fat: 38, fibre: 12)
    let planned = Macros(kcal: 2100, protein: 140, carbs: 230, fat: 65, fibre: 28)
    let over = Macros(kcal: 2400, protein: 150, carbs: 260, fat: 80, fibre: 30)
    return List {
        DaySummaryCard(summary: DaySummary(target: target, eaten: eaten, planned: planned))
        DaySummaryCard(summary: DaySummary(target: target, eaten: over, planned: over))
    }
}
