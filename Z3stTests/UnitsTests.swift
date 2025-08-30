import XCTest
@testable import Z3st

final class UnitsTests: XCTestCase {
    func testRoundTripML() {
        let ml = 750
        XCTAssertEqual(VolumeUnit.ml.toML(VolumeUnit.ml.fromML(ml)), ml)
    }

    func testOzConversion() {
        let ml = 355 // ~12 oz
        let oz = VolumeUnit.oz.fromML(ml)
        let back = VolumeUnit.oz.toML(oz)
        XCTAssertLessThanOrEqual(abs(back - ml), 2)
    }
}
