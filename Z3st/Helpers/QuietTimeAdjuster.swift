import Foundation

enum QuietTimeAdjuster {
    static func nextAllowedDate(after target: Date, quiet: QuietHours) -> Date {
        guard quiet.enabled else { return target }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        func minutes(_ date: Date) -> Int {
            return utc.component(.hour, from: date) * 60 + utc.component(.minute, from: date)
        }
        func toMinutes(_ hhmm: String) -> Int {
            let p = hhmm.split(separator: ":");
            let h = (p.count > 0 ? Int(p[0]) : nil) ?? 0
            let m = (p.count > 1 ? Int(p[1]) : nil) ?? 0
            return h*60 + m
        }
        let t = minutes(target)
        let qs = toMinutes(quiet.startHHmm)
        let qe = toMinutes(quiet.endHHmm)
        let cal = utc
        if qs == qe { return target }
        if qs < qe {
            // Quiet: [qs, qe)
            if t >= qs && t < qe {
                // move to same day at qe
                return cal.date(bySettingHour: qe/60, minute: qe%60, second: 0, of: target) ?? target
            }
            return target
        } else {
            // Quiet wraps midnight: [qs, 24h) U [0, qe)
            if t >= qs {
                // move to next day at qe
                let sameDayEnd = cal.date(bySettingHour: 23, minute: 59, second: 0, of: target) ?? target
                let nextDay = cal.date(byAdding: .day, value: 1, to: sameDayEnd) ?? target
                return cal.date(bySettingHour: qe/60, minute: qe%60, second: 0, of: nextDay) ?? target
            } else if t < qe {
                // move to today at qe
                return cal.date(bySettingHour: qe/60, minute: qe%60, second: 0, of: target) ?? target
            }
            return target
        }
    }
}
