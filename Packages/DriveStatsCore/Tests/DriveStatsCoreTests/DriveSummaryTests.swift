import XCTest
@testable import DriveStatsCore

final class DriveSummaryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func drive(
        startOffset: TimeInterval,
        durationSeconds: TimeInterval,
        distanceMeters: Double,
        topSpeed: Double,
        vehicleID: UUID? = nil
    ) -> Drive {
        Drive(
            startedAt: start.addingTimeInterval(startOffset),
            endedAt: start.addingTimeInterval(startOffset + durationSeconds),
            distanceMeters: distanceMeters,
            topSpeedMetersPerSecond: topSpeed,
            points: [],
            vehicleID: vehicleID
        )
    }

    func testEmptyDrivesYieldEmptySummary() {
        XCTAssertEqual(DriveSummary.compute(from: []), .empty)
    }

    func testAggregatesAcrossDrives() {
        let summary = DriveSummary.compute(from: [
            drive(startOffset: 0, durationSeconds: 600, distanceMeters: 5_000, topSpeed: 25),
            drive(startOffset: 3_600, durationSeconds: 1_800, distanceMeters: 30_000, topSpeed: 38),
            drive(startOffset: 7_200, durationSeconds: 300, distanceMeters: 2_000, topSpeed: 15),
        ])
        XCTAssertEqual(summary.driveCount, 3)
        XCTAssertEqual(summary.totalDistanceMeters, 37_000)
        XCTAssertEqual(summary.totalDuration, 2_700)
        XCTAssertEqual(summary.topSpeedMetersPerSecond, 38)
        XCTAssertEqual(summary.longestDriveMeters, 30_000)
    }

    func testDriveWithoutVehicleIDStillDecodes() throws {
        // Drives saved before the garage milestone have no vehicleID key.
        let legacyJSON = """
        {"id":"11111111-1111-1111-1111-111111111111",
         "startedAt":"2026-07-11T10:00:00Z","endedAt":"2026-07-11T10:30:00Z",
         "distanceMeters":1000,"topSpeedMetersPerSecond":20,"points":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let drive = try decoder.decode(Drive.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(drive.vehicleID)
        XCTAssertEqual(drive.distanceMeters, 1000)
    }
}
