import SwiftData
import SwiftUI

struct RootView: View {
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
