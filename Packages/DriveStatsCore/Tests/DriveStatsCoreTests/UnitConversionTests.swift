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

    func testMetersPerSecondToMilesPerHour() {
        XCTAssertEqual(UnitConversion.milesPerHour(fromMetersPerSecond: 10), 22.36936, accuracy: 0.0001)
    }

    func testMetersToMiles() {
        XCTAssertEqual(UnitConversion.miles(fromMeters: 1609.344), 1, accuracy: 0.0001)
    }
}
