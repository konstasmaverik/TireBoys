import XCTest
@testable import DriveStatsCore

final class JSONDriveStoreTests: XCTestCase {
    private var directory: URL!
    private var store: JSONDriveStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("drive-store-tests-\(UUID().uuidString)")
        store = try JSONDriveStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeDrive(startOffset: TimeInterval = 0) -> Drive {
        let start = Date(timeIntervalSince1970: 1_700_000_000 + startOffset)
        return Drive(
            startedAt: start,
            endedAt: start.addingTimeInterval(600),
            distanceMeters: 12_345,
            topSpeedMetersPerSecond: 33.3,
            points: [
                RoutePoint(
                    timestamp: start, latitude: 37.98, longitude: 23.72,
                    speedMetersPerSecond: 10, horizontalAccuracyMeters: 5
                ),
            ]
        )
    }

    func testSaveThenLoadRoundTrips() throws {
        let drive = makeDrive()
        try store.save(drive)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded, [drive])
    }

    func testLoadAllSortsNewestFirst() throws {
        let older = makeDrive(startOffset: 0)
        let newer = makeDrive(startOffset: 3600)
        try store.save(older)
        try store.save(newer)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.map(\.id), [newer.id, older.id])
    }

    func testDeleteRemovesDrive() throws {
        let drive = makeDrive()
        try store.save(drive)
        try store.delete(id: drive.id)

        XCTAssertEqual(try store.loadAll(), [])
    }

    func testCorruptFileIsSkippedNotFatal() throws {
        let drive = makeDrive()
        try store.save(drive)
        try Data("not json".utf8).write(
            to: directory.appendingPathComponent("corrupt.json")
        )

        XCTAssertEqual(try store.loadAll(), [drive])
    }
}
