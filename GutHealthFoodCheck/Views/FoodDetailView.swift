import SwiftData
import SwiftUI

struct FoodDetailView: View {
    @Environment(\.modelContext) private var context

    let food: FoodItem

    @State private var showingLog = false
    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                summary
            }

            if !food.notes.isEmpty {
                Section("Notes") {
                    Text(food.notes)
                }
            }

            Section("Reactions") {
                if food.logs.isEmpty {
                    Text("No reactions logged yet. Eat a portion, then log how you felt.")
                        .foregroundStyle(.secondary)
                }
                ForEach(food.sortedLogs) { log in
                    LogRow(log: log)
                }
                .onDelete(perform: deleteLogs)
            }
        }
        .navigationTitle(food.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showingLog = true
            } label: {
                Label("Log Reaction", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $showingLog) {
            NavigationStack {
                LogEntryView(food: food)
            }
        }
        .sheet(isPresented: $showingEdit) {
            FoodFormView(food: food)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(food.category.title, systemImage: food.category.systemImage)
                    .foregroundStyle(food.category.color)
                Spacer()
                Text(food.portionLabel)
                    .font(.headline)
            }
            Label(food.tolerance.title, systemImage: food.tolerance.systemImage)
                .font(.title2.bold())
                .foregroundStyle(food.tolerance.color)
            HStack {
                StatView(title: "Logs", value: "\(food.logs.count)")
                StatView(title: "Avg bloating", value: format(food.averageBloating))
                StatView(title: "Avg severity", value: format(food.averageSeverity))
            }
        }
        .padding(.vertical, 4)
    }

    private func format(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "–"
    }

    private func deleteLogs(at offsets: IndexSet) {
        let logs = food.sortedLogs
        for index in offsets {
            let log = logs[index]
            food.logs.removeAll { $0.persistentModelID == log.persistentModelID }
            context.delete(log)
        }
    }
}

private struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LogRow: View {
    let log: SymptomLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.subheadline.bold())
                Spacer()
                if log.onset != .unknown {
                    Label(log.onset.title, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Chip(text: "Bloating \(log.bloating)", color: .forScore(Double(log.bloating)))
                Chip(text: "Pain \(log.pain)", color: .forScore(Double(log.pain)))
                Chip(text: "Gas: \(log.gas.title)", color: .forScore(log.gas.score))
                if log.stool != .notRecorded {
                    Chip(text: log.stool.shortTitle, color: log.stool.isNormal ? .green : .orange)
                }
            }
            if !log.eatenWith.isEmpty {
                Text("With: \(log.eatenWith)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
