import XCTest
@testable import Z3st

final class RemindersEngineTests: XCTestCase {
    func testSuggestTimesPicksFrequentHoursSpaced() {
        var entries: [WaterEntry] = []
        let cal = Calendar.current
        let now = Date()
        for dayOffset in 0..<7 {
            let base = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            let nine = cal.date(bySettingHour: 9, minute: 10, second: 0, of: base)!
            let twelve = cal.date(bySettingHour: 12, minute: 0, second: 0, of: base)!
            let fifteen = cal.date(bySettingHour: 15, minute: 30, second: 0, of: base)!
            let userId = UUID()
            entries.append(.init(id: UUID(), user_id: userId, volume_ml: 250, created_at: nine))
            entries.append(.init(id: UUID(), user_id: userId, volume_ml: 250, created_at: twelve))
            entries.append(.init(id: UUID(), user_id: userId, volume_ml: 250, created_at: fifteen))
        }
        let times = RemindersEngine.suggestTimes(from: entries)
        XCTAssertFalse(times.isEmpty)
        // Should include around 9, 12, 15
        let hours = times.compactMap { Int($0.prefix(2)) }
        XCTAssertTrue(hours.contains(9) || hours.contains(10))
        XCTAssertTrue(hours.contains(12) || hours.contains(11))
        XCTAssertTrue(hours.contains(15) || hours.contains(14) || hours.contains(16))
        // Ensure spacing roughly >= 2h
        for i in 0..<hours.count { for j in i+1..<hours.count { XCTAssertGreaterThanOrEqual(abs(hours[i]-hours[j]), 2) } }
    }
}

