import XCTest
@testable import Z3st

final class ReminderHelpersTests: XCTestCase {
    func testFilterRespectsQuietWrap() {
        let times = ["06:30","07:00","21:30","22:30"]
        let quiet = QuietHours(enabled: true, startHHmm: "22:00", endHHmm: "07:00")
        let filtered = ReminderHelpers.filter(times: times, by: quiet)
        XCTAssertTrue(filtered.contains("07:00"))
        XCTAssertTrue(filtered.contains("21:30"))
        XCTAssertFalse(filtered.contains("06:30"))
        XCTAssertFalse(filtered.contains("22:30"))
    }

    func testFilterDisabledReturnsSame() {
        let times = ["09:00","12:00"]
        let quiet = QuietHours(enabled: false, startHHmm: "00:00", endHHmm: "00:00")
        XCTAssertEqual(ReminderHelpers.filter(times: times, by: quiet), times)
    }
}

