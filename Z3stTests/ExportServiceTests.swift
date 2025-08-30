import XCTest
@testable import Z3st

final class ExportServiceTests: XCTestCase {
    func testCSVBuild() {
        let rows = [
            WaterDayTotal(dateString: "2025-08-01", total_ml: 1000),
            WaterDayTotal(dateString: "2025-08-02", total_ml: 1500)
        ]
        let csv = ExportService.buildCSV(from: rows)
        XCTAssertTrue(csv.contains("date,total_ml"))
        XCTAssertTrue(csv.contains("2025-08-01,1000"))
        XCTAssertTrue(csv.contains("2025-08-02,1500"))
    }
}

