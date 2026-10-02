import SwiftData
import SwiftUI

struct FoodListView: View {
    @Environment(\.modelContext) private var context
    @Query private var foods: [FoodItem]

    /// Comma-separated raw values of collapsed sections, so the layout survives relaunches.
    @AppStorage("collapsedCategories") private var collapsedRaw = ""
    @State private var searchText = ""
    @State private var showingAddFood = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleCategories) { category in
                    let rows = items(in: category)
                    Section(isExpanded: isExpanded(category)) {
                        if rows.isEmpty {
                            Text("No foods yet")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(rows) { food in
                            NavigationLink(value: food) {
                                FoodRow(food: food)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets.map { rows[$0] })
                        }
                    } header: {
                        CategoryHeader(category: category, count: rows.count)
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if !searchText.isEmpty && visibleCategories.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Gut Check")
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food)
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Label("Add Food", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                FoodFormView()
            }
        }
    }

    private var filteredFoods: [FoodItem] {
        let query = FoodItem.normalizedName(searchText)
        let matching = query.isEmpty
            ? foods
            : foods.filter { FoodItem.normalizedName($0.name).contains(query) }
        return matching.sorted {
            let order = $0.name.localizedCaseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.portion < $1.portion : order == .orderedAscending
        }
    }

    private var visibleCategories: [FODMAPCategory] {
        guard !searchText.isEmpty else { return FODMAPCategory.allCases }
        let used = Set(filteredFoods.map(\.category))
        return FODMAPCategory.allCases.filter { used.contains($0) }
    }

    private func items(in category: FODMAPCategory) -> [FoodItem] {
        filteredFoods.filter { $0.category == category }
    }

    private func isExpanded(_ category: FODMAPCategory) -> Binding<Bool> {
        Binding {
            // Always show search results, even in collapsed sections.
            !searchText.isEmpty || !collapsedCategories.contains(category.rawValue)
        } set: { expanded in
            var collapsed = collapsedCategories
            if expanded {
                collapsed.remove(category.rawValue)
            } else {
                collapsed.insert(category.rawValue)
            }
            collapsedRaw = collapsed.sorted().joined(separator: ",")
        }
    }

    private var collapsedCategories: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    private func delete(_ items: [FoodItem]) {
        for item in items {
            context.delete(item)
        }
    }
}

private struct CategoryHeader: View {
    let category: FODMAPCategory
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.systemImage)
                .foregroundStyle(category.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(category.color.opacity(0.15), in: Capsule())
                .foregroundStyle(category.color)
        }
        .textCase(nil)
    }
}

private struct FoodRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(food.tolerance.title, systemImage: food.tolerance.systemImage)
                .labelStyle(.iconOnly)
                .foregroundStyle(food.tolerance.color)
                .font(.title3)
                .accessibilityLabel(food.tolerance.title)
        }
    }

    private var subtitle: String {
        var parts = [food.portionLabel]
        if let bloating = food.averageBloating {
            parts.append("avg bloating \(bloating.formatted(.number.precision(.fractionLength(0...1))))")
        }
        parts.append(food.logs.count == 1 ? "1 log" : "\(food.logs.count) logs")
        return parts.joined(separator: " · ")
    }
}

#Preview {
    FoodListView()
        .modelContainer(for: [FoodItem.self, SymptomLog.self], inMemory: true)
}
