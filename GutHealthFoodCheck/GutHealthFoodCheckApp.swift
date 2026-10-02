import SwiftData
import SwiftUI
import UserNotifications

@main
struct GutHealthFoodCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer = {
        do {
            return try SharedStore.makeContainer()
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case today
    case plan
    case foods
}

/// Lets notifications and the widget open the check-in.
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selectedTab: AppTab = .today
    var showCheckIn = false

    func openCheckIn() {
        selectedTab = .today
        showCheckIn = true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show the reminder as a banner even when the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            AppRouter.shared.openCheckIn()
        }
    }
}
