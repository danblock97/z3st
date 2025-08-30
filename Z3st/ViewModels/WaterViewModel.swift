import Foundation

@MainActor
final class WaterViewModel: ObservableObject {
    @Published var todayTotal: Int = 0
    @Published var history: [WaterDayTotal] = []
    @Published var loading: Bool = false

    func refresh(range: HistoryRange) async {
        loading = true
        defer { loading = false }
        do {
            let now = Date()
            let start = range.startDate(from: now)
            let totals = try await WaterService.shared.fetchDayTotals(rangeStart: start, rangeEnd: now)
            history = totals
            let todayStr = ISO8601DateFormatter.dateFormatterYYYYMMDD.string(from: now)
            todayTotal = totals.first(where: { $0.dateString == todayStr })?.total_ml ?? 0
            AppGroupManager.setTodayTotal(todayTotal)
        } catch {
            // swallow for now
        }
    }

    func log(amount: Int) async -> Bool {
        do {
            try await WaterService.shared.logWater(volumeML: amount)
            // Reschedule interval reminders from now based on current settings
            let interval = UserDefaults.standard.integer(forKey: "reminder_interval_minutes")
            let minutes = (interval >= 5 ? interval : 30)
            let quiet = QuietHours(
                enabled: UserDefaults.standard.bool(forKey: "quiet_enabled"),
                startHHmm: UserDefaults.standard.string(forKey: "quiet_start") ?? "22:00",
                endHHmm: UserDefaults.standard.string(forKey: "quiet_end") ?? "07:00"
            )
            NotificationService.shared.scheduleIntervalNotifications(every: minutes, quiet: quiet)
            NotificationService.shared.scheduleInactivityNudge(after: 2)
            await refresh(range: .last7D)
            return true
        } catch {
            return false
        }
    }
}

enum HistoryRange: String, CaseIterable {
    case last7D = "7D"
    case last30D = "30D"
    case last1Y = "1Y"
    case all = "All"

    func startDate(from now: Date) -> Date {
        var cal = Calendar.current
        switch self {
        case .last7D: return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .last30D: return cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now
        case .last1Y: return cal.date(byAdding: .year, value: -1, to: now) ?? now
        case .all: return Date(timeIntervalSince1970: 0)
        }
    }
}
