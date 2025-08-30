import Foundation

enum RemindersEngine {
    // Suggest up to N daily times (HH:mm) based on historical entry timestamps.
    // Simple heuristic: histogram by hour, pick top hours spaced at least 90 minutes apart.
    static func suggestTimes(from entries: [WaterEntry], maxCount: Int = 5) -> [String] {
        guard !entries.isEmpty else { return ["09:00","11:30","14:00","16:30","19:00"] }
        var counts = Array(repeating: 0, count: 24)
        let cal = Calendar.current
        for e in entries {
            let h = cal.component(.hour, from: e.created_at)
            counts[h] += 1
        }
        // Rank hours by frequency, then greedily pick spaced hours
        let ranked = counts.enumerated().sorted { $0.element > $1.element }.map { $0.offset }
        var picked: [Int] = []
        for hour in ranked {
            if picked.count >= maxCount { break }
            if picked.allSatisfy({ abs($0 - hour) >= 2 && abs(($0 + 24) - hour) >= 2 && abs(($0 - 24) - hour) >= 2 }) {
                picked.append(hour)
            }
        }
        if picked.isEmpty { picked = [9, 11, 14, 16, 19] }
        // Add a consistent minute offset based on median minute in data to avoid all on the hour
        let minutes = entries.map { Calendar.current.component(.minute, from: $0.created_at) }.sorted()
        let minute: Int
        if minutes.isEmpty { minute = 0 } else { minute = minutes[minutes.count/2] / 5 * 5 } // round to nearest 5
        return picked.sorted().map { String(format: "%02d:%02d", $0, minute) }
    }
}

