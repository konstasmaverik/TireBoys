import XCTest
@testable import DriveStatsCore

final class UnitConversionTests: XCTestCase {
    func testMetersPerSecondToKilometersPerHour() {
        XCTAssertEqual(UnitConversion.kilometersPerHour(fromMetersPerSecond: 10), 36, accuracy: 0.0001)
    }

    func testInvalidSpeedSentinelStaysNegative() {
        XCTAssertLessThan(UnitConversion.kilometersPerHour(fromMetersPerSecond: -1), 0)
    }

    func testMetersToKilometers() {
        XCTAssertEqual(UnitConversion.kilometers(fromMeters: 1500), 1.5, accuracy: 0.0001)
    }
}
