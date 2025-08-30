import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    func scheduleDailyNotifications(at times: [DateComponents], identifierPrefix: String, quiet: QuietHours? = nil) {
        let center = UNUserNotificationCenter.current()
        // Clear existing for prefix
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.hasPrefix(identifierPrefix) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
            let filtered = times.filter { comps in
                guard let quiet, quiet.enabled else { return true }
                return !quiet.contains(comps)
            }
            for (i, comps) in filtered.enumerated() {
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let content = UNMutableNotificationContent()
                content.title = "Time to drink water"
                content.body = "Stay hydrated. Log your intake in Z3st."
                content.sound = .default
                content.categoryIdentifier = "WATER_REMINDER"
                let request = UNNotificationRequest(identifier: "\(identifierPrefix)_\(i)", content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    func scheduleIntervalNotifications(every minutes: Int, identifierPrefix: String = "interval", quiet: QuietHours) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.hasPrefix(identifierPrefix) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)

            // Build up to system limit (~64) next notifications outside quiet hours
            let content = UNMutableNotificationContent()
            content.title = "Time to drink water"
            content.body = "Stay hydrated. Log your intake in Z3st."
            content.sound = .default
            content.categoryIdentifier = "WATER_REMINDER"

            let step: TimeInterval = Double(minutes * 60)
            var scheduled = 0
            var next = Date().addingTimeInterval(step)
            let cal = Calendar.current
            while scheduled < 64 {
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                let insideQuiet = quiet.enabled ? quiet.contains(hour: comps.hour ?? 0, minute: comps.minute ?? 0) : false
                if !insideQuiet {
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(identifier: "\(identifierPrefix)_\(scheduled)", content: content, trigger: trigger)
                    center.add(request)
                    scheduled += 1
                }
                next = next.addingTimeInterval(step)
            }
        }
    }

    func scheduleInactivityNudge(after hours: Int, identifier: String = "inactivity_nudge") {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Hydration nudge"
        content.body = "Haven't logged water in a while. Take a sip!"
        content.sound = .default
        var interval = TimeInterval(hours * 3600)
        // Avoid quiet hours if configured
        let quiet = QuietHours(
            enabled: UserDefaults.standard.bool(forKey: "quiet_enabled"),
            startHHmm: UserDefaults.standard.string(forKey: "quiet_start") ?? "22:00",
            endHHmm: UserDefaults.standard.string(forKey: "quiet_end") ?? "07:00"
        )
        if quiet.enabled {
            let now = Date()
            let target = now.addingTimeInterval(interval)
            let adjusted = QuietTimeAdjuster.nextAllowedDate(after: target, quiet: quiet)
            interval = max(60, adjusted.timeIntervalSince(now))
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        content.categoryIdentifier = "WATER_REMINDER"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    

    // Foreground presentation
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async {
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task {
            switch response.actionIdentifier {
            case "LOG_250":
                try? await WaterService.shared.logWater(volumeML: 250)
                await MainActor.run { AppState.shared.selectedTab = .log }
            case "LOG_500":
                try? await WaterService.shared.logWater(volumeML: 500)
                await MainActor.run { AppState.shared.selectedTab = .log }
            default:
                // Tapping the notification body opens Log tab
                await MainActor.run { AppState.shared.selectedTab = .log }
            }
            await MainActor.run { completionHandler() }
        }
    }

    private func registerCategories() {
        let unitRaw = UserDefaults.standard.string(forKey: "unit") ?? VolumeUnit.ml.rawValue
        let unit = VolumeUnit(rawValue: unitRaw) ?? .ml
        let t250 = unit == .ml ? "Log 250 mL" : String(format: "Log %.0f oz", unit.fromML(250))
        let t500 = unit == .ml ? "Log 500 mL" : String(format: "Log %.0f oz", unit.fromML(500))
        let log250 = UNNotificationAction(identifier: "LOG_250", title: t250, options: [])
        let log500 = UNNotificationAction(identifier: "LOG_500", title: t500, options: [])
        let category = UNNotificationCategory(identifier: "WATER_REMINDER", actions: [log250, log500], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
