import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(Profile.storageKey) private var profileRaw = ""

    var body: some View {
        Group {
            switch Profile(rawValue: profileRaw) {
            case .amel:
                AmelTabs()
            case .nina:
                NinaHomeView()
            case nil:
                ProfilePickerView()
            }
        }
        .task { MealPlanSeeder.seedIfNeeded(context) }
    }
}

/// Amel's gut program tabs. Seeding, reminders and deep links live here so Nina never triggers them.
private struct AmelTabs: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var router = AppRouter.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)
            PlanView()
                .tabItem { Label("Plan", systemImage: "list.number") }
                .tag(AppTab.plan)
            FoodListView()
                .tabItem { Label("Foods", systemImage: "fork.knife") }
                .tag(AppTab.foods)
        }
        .task {
            ProgramActions.seedIfNeeded(context)
            if ReminderScheduler.isEnabled {
                await ReminderScheduler.requestAuthorization()
            }
            ProgramActions.refreshReminders(context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ProgramActions.refreshReminders(context)
            }
        }
        .onOpenURL { url in
            if url.host == "checkin" {
                router.openCheckIn()
            }
        }
    }
}
