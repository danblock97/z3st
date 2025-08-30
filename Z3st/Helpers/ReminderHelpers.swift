import Foundation

enum ReminderHelpers {
    static func filter(times: [String], by quiet: QuietHours) -> [String] {
        guard quiet.enabled else { return times }
        return times.filter { str in
            let p = str.split(separator: ":")
            guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]) else { return false }
            return !quiet.contains(hour: h, minute: m)
        }
    }
}

