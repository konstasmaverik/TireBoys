import XCTest
@testable import DriveStatsCore

final class DriveAccumulatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func point(
        secondsAfterStart: TimeInterval,
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

    func testAccumulatesDistanceAcrossAcceptedPoints() {
        var accumulator = DriveAccumulator(startedAt: start)
        // Three fixes each 0.0001° of latitude apart ≈ 11.1 m per step.
        accumulator.add(point(secondsAfterStart: 0, latitude: 37.9800))
        accumulator.add(point(secondsAfterStart: 1, latitude: 37.9801))
        accumulator.add(point(secondsAfterStart: 2, latitude: 37.9802))

        XCTAssertEqual(accumulator.points.count, 3)
        XCTAssertEqual(accumulator.distanceMeters, 22.2, accuracy: 0.5)
    }

    func testTracksTopSpeedIgnoringInvalidFixes() {
        var accumulator = DriveAccumulator(startedAt: start)
        accumulator.add(point(secondsAfterStart: 0, latitude: 37.9800, speed: 20))
        accumulator.add(point(secondsAfterStart: 1, latitude: 37.9801, speed: -1))
        accumulator.add(point(secondsAfterStart: 2, latitude: 37.9802, speed: 35))

        XCTAssertEqual(accumulator.topSpeedMetersPerSecond, 35)
    }

    func testRejectedPointAddsNoDistance() {
        var accumulator = DriveAccumulator(startedAt: start)
        accumulator.add(point(secondsAfterStart: 0, latitude: 37.9800))
        let rejection = accumulator.add(
            point(secondsAfterStart: 1, latitude: 37.9900) // ~1.1 km teleport
        )

        XCTAssertEqual(rejection, .implausibleJump)
        XCTAssertEqual(accumulator.points.count, 1)
        XCTAssertEqual(accumulator.distanceMeters, 0, accuracy: 0.001)
    }

    func testFinishProducesDriveWithTotals() {
        var accumulator = DriveAccumulator(startedAt: start)
        accumulator.add(point(secondsAfterStart: 0, latitude: 37.9800, speed: 15))
        accumulator.add(point(secondsAfterStart: 60, latitude: 37.9810, speed: 25))

        let drive = accumulator.finish(at: start.addingTimeInterval(60))

        XCTAssertEqual(drive.startedAt, start)
        XCTAssertEqual(drive.duration, 60, accuracy: 0.001)
        XCTAssertEqual(drive.topSpeedMetersPerSecond, 25)
        XCTAssertEqual(drive.distanceMeters, 111.2, accuracy: 1)
        XCTAssertEqual(drive.averageSpeedMetersPerSecond, 111.2 / 60, accuracy: 0.05)
        XCTAssertEqual(drive.points.count, 2)
    }
}
