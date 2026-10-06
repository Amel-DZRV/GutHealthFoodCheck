import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Sheet that imports meal-plan.json, replacing the current meal plan after confirmation.
struct ImportPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var meals: [MealDefinition]

    @State private var showingPicker = false
    @State private var confirmingReplace = false
    @State private var result: ImportResult?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose the meal-plan.json file to import. It holds the meals, ingredients, daily targets and weekly plans for Amel and Nina.")
                    Button("Choose file") {
                        if meals.isEmpty {
                            showingPicker = true
                        } else {
                            confirmingReplace = true
                        }
                    }
                }
                if let result {
                    Section("Result") {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Text(message)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Import plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Replace the current meal plan?", isPresented: $confirmingReplace) {
                Button("Replace", role: .destructive) { showingPicker = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Replace the current meal plan? Checkmarks and edits are removed. Shopping items you added yourself are kept.")
            }
            .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.json]) { picked in
                handle(picked)
            }
        }
    }

    private func handle(_ picked: Result<URL, Error>) {
        switch picked {
        case .failure(let error):
            result = .failure(error.localizedDescription)
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let summary = try MealPlanImporter.importPlan(data: data, into: context, now: .now)
                result = .success(message(for: summary))
            } catch {
                result = .failure(error.localizedDescription)
            }
        }
    }

    private func message(for summary: MealPlanImportSummary) -> String {
        let names: [String] = summary.people.sorted().map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }
        let who = names.count == 2 ? "\(names[0]) and \(names[1])" : names.joined(separator: ", ")
        return who.isEmpty
            ? "Imported \(summary.meals) meals"
            : "Imported \(summary.meals) meals for \(who)"
    }
}

private enum ImportResult {
    case success(String)
    case failure(String)
}
