import Foundation
import UserNotifications

/// Schedules the evening check-in as real banner notifications, one per day for the next two weeks.
/// Rescheduled whenever data changes or the app opens, so today's text reflects the current test
/// and today's reminder is dropped once you've logged.
enum ReminderScheduler {
    static let enabledKey = "reminderEnabled"
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"

    private static let daysAhead = 14
    private static let idPrefix = "checkin-"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var hour: Int {
        UserDefaults.standard.object(forKey: hourKey) as? Int ?? 20
    }

    static var minute: Int {
        UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 0
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(loggedToday: Bool, todayTitle: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        )
        center.removeAllDeliveredNotifications()

        guard isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }
            if offset == 0 && (loggedToday || fireDate <= now) { continue }

            let content = UNMutableNotificationContent()
            content.title = "Evening check-in"
            content.body = offset == 0
                ? "\(todayTitle): how were bloating and gas today?"
                : "How were bloating and gas today? It takes 10 seconds."
            content.sound = .default
            content.interruptionLevel = .active

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = idPrefix + fireDate.formatted(.iso8601.year().month().day())
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
