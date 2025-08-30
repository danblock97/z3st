import XCTest
@testable import Z3st

final class QuietTimeAdjusterTests: XCTestCase {
    func testAdjustWithinDayWindow() {
        let q = QuietHours(enabled: true, startHHmm: "13:00", endHHmm: "15:00")
        let base = ISO8601DateFormatter().date(from: "2025-08-30T14:10:00Z")!
        let adjusted = QuietTimeAdjuster.nextAllowedDate(after: base, quiet: q)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.hour,.minute], from: adjusted)
        XCTAssertEqual(comps.hour, 15)
        XCTAssertEqual(comps.minute, 0)
    }

    func testAdjustWrapsMidnight() {
        let q = QuietHours(enabled: true, startHHmm: "22:00", endHHmm: "07:00")
        let base = ISO8601DateFormatter().date(from: "2025-08-30T22:30:00Z")!
        let adjusted = QuietTimeAdjuster.nextAllowedDate(after: base, quiet: q)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.hour], from: adjusted)
        XCTAssertEqual(comps.hour, 7)
    }

    func testNoAdjustmentOutsideQuiet() {
        let q = QuietHours(enabled: true, startHHmm: "22:00", endHHmm: "07:00")
        let base = ISO8601DateFormatter().date(from: "2025-08-30T12:30:00Z")!
        let adjusted = QuietTimeAdjuster.nextAllowedDate(after: base, quiet: q)
        XCTAssertEqual(base, adjusted)
    }
}
