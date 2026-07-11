import XCTest
@testable import DriveStatsCore

final class GPSFilterTests: XCTestCase {
    private let filter = GPSFilter()
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func point(
        secondsAfterStart: TimeInterval = 0,
        latitude: Double = 37.98,
        longitude: Double = 23.72,
        speed: Double = 10,
        accuracy: Double = 5
    ) -> RoutePoint {
        RoutePoint(
            timestamp: start.addingTimeInterval(secondsAfterStart),
            latitude: latitude,
            longitude: longitude,
            speedMetersPerSecond: speed,
            horizontalAccuracyMeters: accuracy
        )
    }

    func testAcceptsGoodFirstPoint() {
        XCTAssertNil(filter.evaluate(point(), previous: nil))
    }

    func testRejectsPoorAccuracy() {
        XCTAssertEqual(filter.evaluate(point(accuracy: 80), previous: nil), .poorAccuracy)
    }

    func testRejectsInvalidNegativeAccuracy() {
        XCTAssertEqual(filter.evaluate(point(accuracy: -1), previous: nil), .poorAccuracy)
    }

    func testRejectsStaleOrDuplicateTimestamp() {
        let previous = point(secondsAfterStart: 10)
        XCTAssertEqual(
            filter.evaluate(point(secondsAfterStart: 10), previous: previous),
            .notNewerThanPrevious
        )
    }

    func testRejectsTeleportJump() {
        // ~1.1 km displacement in 1 second is far beyond any plausible car speed.
        let previous = point(secondsAfterStart: 0)
        let teleported = point(secondsAfterStart: 1, latitude: 37.99)
        XCTAssertEqual(filter.evaluate(teleported, previous: previous), .implausibleJump)
    }

    func testAcceptsNormalHighwayMovement() {
        // ~33 m in 1 s ≈ 120 km/h.
        let previous = point(secondsAfterStart: 0)
        let next = point(secondsAfterStart: 1, latitude: 37.9803)
        XCTAssertNil(filter.evaluate(next, previous: previous))
    }
}
