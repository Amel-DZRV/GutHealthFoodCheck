import SwiftUI

/// One meal in a day list. The parent wraps it in a NavigationLink; only the check button toggles.
struct MealRowView: View {
    let title: String
    let name: String
    let summary: String
    let kcal: Double
    let isEaten: Bool
    var testAddition: String? = nil
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.headline)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                    .font(.subheadline)
                if let testAddition, !testAddition.isEmpty {
                    Label(testAddition, systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }
            Spacer(minLength: 0)
            Button(action: onToggle) {
                Image(systemName: isEaten ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isEaten ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(.success, trigger: isEaten)
            .accessibilityLabel(isEaten ? "Mark as not eaten" : "Mark as eaten")
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        MealRowView(
            title: "Breakfast", name: "Eggs and skyr", summary: "Eggs + Butter + Skyr …",
            kcal: 520, isEaten: true, onToggle: {}
        )
        MealRowView(
            title: "Pre-workout", name: "Rice cakes", summary: "Rice cakes + Honey",
            kcal: 210, isEaten: false, testAddition: "Garlic 1 clove", onToggle: {}
        )
    }
}
