import Foundation
import BackgroundTasks

final class BackgroundTaskService {
    static let shared = BackgroundTaskService()
    private let refreshIdentifier = "com.z3st.refresh"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600) // ~6h
        do { try BGTaskScheduler.shared.submit(request) } catch { /* ignore */ }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        schedule() // schedule next
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation {
            Task { @MainActor in
                // Top up interval-based reminders
                await WaterService.shared.syncPending()
                let interval = UserDefaults.standard.integer(forKey: "reminder_interval_minutes")
                let minutes = (interval >= 5 ? interval : 30)
                let quiet = QuietHours(
                    enabled: UserDefaults.standard.bool(forKey: "quiet_enabled"),
                    startHHmm: UserDefaults.standard.string(forKey: "quiet_start") ?? "22:00",
                    endHHmm: UserDefaults.standard.string(forKey: "quiet_end") ?? "07:00"
                )
                // Kickoff at 8am if not quiet
                var eight = DateComponents(); eight.hour = 8; eight.minute = 0
                NotificationService.shared.scheduleDailyNotifications(at: [], identifierPrefix: "kickoff")
                if !quiet.contains(eight) {
                    NotificationService.shared.scheduleDailyNotifications(at: [eight], identifierPrefix: "kickoff", quiet: quiet)
                }
                NotificationService.shared.scheduleIntervalNotifications(every: minutes, quiet: quiet)
                task.setTaskCompleted(success: true)
            }
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        queue.addOperation(operation)
    }
}
