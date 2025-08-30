import SwiftUI

struct RemindersView: View {
    @AppStorage("reminders_enabled") private var enabled: Bool = true
    @AppStorage("inactivity_hours") private var inactivityHours: Int = ReminderPreferences.default.inactivityHours
    @AppStorage("reminder_interval_minutes") private var intervalMinutes: Int = 30
    @AppStorage("quiet_enabled") private var quietEnabled: Bool = false
    @AppStorage("quiet_start") private var quietStart: String = "22:00"
    @AppStorage("quiet_end") private var quietEnd: String = "07:00"

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Reminders")) {
                    Toggle("Enable reminders", isOn: $enabled)
                    Stepper(value: $intervalMinutes, in: 5...120, step: 5) { Text("Every \(intervalMinutes) min") }
                    Stepper(value: $inactivityHours, in: 1...6) { Text("Nudge after \(inactivityHours)h of inactivity") }
                }
                Section(header: Text("Settings")) {
                    NavigationLink(destination: SettingsView()) { Label("Quiet hours", systemImage: "moon.zzz.fill") }
                }
                Section {
                    Button("Apply Schedule") { schedule() }
                }
            }
            .navigationTitle("Reminders")
            .onAppear { schedule() }
            .onChange(of: intervalMinutes) { _, _ in schedule() }
            .onChange(of: enabled) { _, _ in schedule() }
        }
    }

    private func schedule() {
        guard enabled else { return }
        // Clear any previous daily schedules
        NotificationService.shared.scheduleDailyNotifications(at: [], identifierPrefix: "daily")
        NotificationService.shared.scheduleDailyNotifications(at: [], identifierPrefix: "kickoff")
        // Schedule interval-based reminders with quiet hours respected (up to system limit)
        let quiet = QuietHours(enabled: quietEnabled, startHHmm: quietStart, endHHmm: quietEnd)
        // 8am kickoff if not in quiet hours
        var eight = DateComponents(); eight.hour = 8; eight.minute = 0
        if !quiet.contains(eight) {
            NotificationService.shared.scheduleDailyNotifications(at: [eight], identifierPrefix: "kickoff", quiet: quiet)
        }
        NotificationService.shared.scheduleIntervalNotifications(every: intervalMinutes, quiet: quiet)
        NotificationService.shared.scheduleInactivityNudge(after: inactivityHours)
        NotificationService.shared.requestAuthorizationIfNeeded()
    }
}
