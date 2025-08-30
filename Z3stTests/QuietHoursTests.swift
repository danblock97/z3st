import XCTest
@testable import Z3st

final class QuietHoursTests: XCTestCase {
    func testContainsWithinSimpleWindow() {
        let q = QuietHours(enabled: true, startHHmm: "22:00", endHHmm: "07:00")
        XCTAssertTrue(q.contains(hour: 23, minute: 0))
        XCTAssertTrue(q.contains(hour: 6, minute: 59))
        XCTAssertFalse(q.contains(hour: 12, minute: 0))
    }

    func testContainsNoWrap() {
        let q = QuietHours(enabled: true, startHHmm: "13:00", endHHmm: "15:00")
        XCTAssertTrue(q.contains(hour: 13, minute: 0))
        XCTAssertTrue(q.contains(hour: 14, minute: 59))
        XCTAssertFalse(q.contains(hour: 15, minute: 0))
        XCTAssertFalse(q.contains(hour: 12, minute: 59))
    }
}

