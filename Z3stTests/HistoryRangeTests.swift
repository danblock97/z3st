import XCTest
@testable import Z3st

final class HistoryRangeTests: XCTestCase {
    func testStartDate7D() {
        let now = ISO8601DateFormatter().date(from: "2025-08-30T12:00:00Z")!
        let start = HistoryRange.last7D.startDate(from: now)
        let df = ISO8601DateFormatter.dateFormatterYYYYMMDD
        XCTAssertEqual(df.string(from: start), "2025-08-24")
    }

    func testStartDate30D() {
        let now = ISO8601DateFormatter().date(from: "2025-08-30T12:00:00Z")!
        let start = HistoryRange.last30D.startDate(from: now)
        let df = ISO8601DateFormatter.dateFormatterYYYYMMDD
        XCTAssertEqual(df.string(from: start), "2025-08-01")
    }
}

