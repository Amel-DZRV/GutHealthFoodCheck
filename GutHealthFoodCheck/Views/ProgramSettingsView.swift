import SwiftData
import SwiftUI
import UserNotifications

struct ProgramSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query private var settingsList: [ProgramSettings]

    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = true
    @AppStorage(ReminderScheduler.hourKey) private var reminderHour = 20
    @AppStorage(ReminderScheduler.minuteKey) private var reminderMinute = 0
    @State private var notificationsDenied = false
    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            Form {
                reminderSection
                mealPlanSection
                if let settings = settingsList.first {
                    ProgramFields(settings: settings)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        ProgramActions.didChange(context)
                        dismiss()
                    }
                }
            }
            .task { await checkNotificationPermission() }
            .sheet(isPresented: $showingImport) {
                ImportPlanView()
            }
        }
    }

    private var mealPlanSection: some View {
        Section("Meal plan") {
            NavigationLink("Meal plan settings") {
                MealPlanSettingsView(profile: .amel)
            }
            Button("Import plan") {
                showingImport = true
            }
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Evening reminder", isOn: $remindersEnabled)
            if remindersEnabled {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
            if notificationsDenied {
                Button("Notifications are off. Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        } header: {
            Text("Check-in reminder")
        } footer: {
            Text("A banner notification each evening, skipped once you've logged that day.")
        }
        .onChange(of: remindersEnabled) { _, enabled in
            Task {
                if enabled { await ReminderScheduler.requestAuthorization() }
                await checkNotificationPermission()
                ProgramActions.refreshReminders(context)
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderHour = parts.hour ?? 20
            reminderMinute = parts.minute ?? 0
        }
    }

    private func checkNotificationPermission() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsDenied = remindersEnabled && status == .denied
    }
}

private struct ProgramFields: View {
    @Bindable var settings: ProgramSettings

    var body: some View {
        Section {
            DatePicker("Baseline starts", selection: $settings.baselineStart, displayedComponents: .date)
                .disabled(settings.reintroStart != nil)
            if let start = settings.reintroStart {
                LabeledContent("Reintroduction started", value: start.formatted(date: .abbreviated, time: .omitted))
                Button("Go back to baseline", role: .destructive) {
                    settings.reintroStart = nil
                }
            }
        } header: {
            Text("Program")
        } footer: {
            if settings.reintroStart != nil {
                Text("Going back to baseline only works cleanly before any test days are logged.")
            }
        }

        Section("Standard breakfast") {
            TextField("e.g. 2 eggs, 40 g sourdough spelt toast", text: $settings.breakfast, axis: .vertical)
        }
        Section("Standard lunch") {
            TextField("Lunch", text: $settings.lunch, axis: .vertical)
        }
        Section("Standard dinner") {
            TextField("e.g. salmon, potato, green beans", text: $settings.dinner, axis: .vertical)
        }
    }
}
