import Foundation

struct QuietHours: Equatable, Codable {
    var enabled: Bool
    var startHHmm: String // e.g., "22:00"
    var endHHmm: String   // e.g., "07:00"

    func contains(hour: Int, minute: Int) -> Bool {
        guard enabled else { return false }
        func toMinutes(_ hhmm: String) -> Int? {
            let p = hhmm.split(separator: ":");
            guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]) else { return nil }
            return h*60 + m
        }
        guard let start = toMinutes(startHHmm), let end = toMinutes(endHHmm) else { return false }
        let t = hour*60 + minute
        if start == end { return false } // disabled-like
        if start < end {
            return (t >= start && t < end)
        } else { // wraps midnight
            return (t >= start || t < end)
        }
    }

    func contains(_ comps: DateComponents) -> Bool {
        contains(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
}

extension QuietHours {
    static let `default` = QuietHours(enabled: false, startHHmm: "22:00", endHHmm: "07:00")
}

