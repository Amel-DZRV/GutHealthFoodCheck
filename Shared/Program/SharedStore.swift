import Foundation
import SwiftData

/// The SwiftData store, kept in the App Group container so the widget can read it.
enum SharedStore {
    static let appGroupID = "group.com.guthealth.GutHealthFoodCheck"

    static let schema = Schema([
        FoodItem.self,
        SymptomLog.self,
        DailyCheckIn.self,
        ReintroTest.self,
        ProgramSettings.self,
    ])

    static func makeContainer() throws -> ModelContainer {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
            let configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
            return try ModelContainer(for: schema, configurations: configuration)
        }
        // App Group not provisioned (e.g. free developer account): the app still works, the widget can't see data.
        let configuration = ModelConfiguration(schema: schema, groupContainer: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func fetchAll(_ context: ModelContext) -> (ProgramSettings?, [DailyCheckIn], [ReintroTest]) {
        let settings = try? context.fetch(FetchDescriptor<ProgramSettings>()).first
        let checkIns = (try? context.fetch(FetchDescriptor<DailyCheckIn>(sortBy: [SortDescriptor(\.day)]))) ?? []
        let tests = (try? context.fetch(FetchDescriptor<ReintroTest>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return (settings, checkIns, tests)
    }

    static func engine(_ context: ModelContext) -> ProgramEngine {
        let (settings, checkIns, tests) = fetchAll(context)
        return ProgramEngine(settings: settings, checkIns: checkIns, tests: tests)
    }
}
