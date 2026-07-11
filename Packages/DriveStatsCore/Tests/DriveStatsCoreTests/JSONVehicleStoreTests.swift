import XCTest
@testable import DriveStatsCore

final class JSONVehicleStoreTests: XCTestCase {
    private var directory: URL!
    private var store: JSONVehicleStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vehicles-\(UUID().uuidString)")
        store = try JSONVehicleStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // ISO8601 dates truncate to whole seconds, so round-trip tests use
    // whole-second timestamps rather than Date().
    private let wholeSecondDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testSaveThenLoadRoundTrips() throws {
        let vehicle = Vehicle(make: "Toyota", model: "Supra", year: 1998, createdAt: wholeSecondDate)
        try store.save(vehicle)
        XCTAssertEqual(try store.loadAll(), [vehicle])
    }

    func testLoadAllSortsOldestFirst() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Vehicle(make: "Mazda", model: "MX-5", year: 2019, createdAt: base.addingTimeInterval(60))
        let first = Vehicle(make: "BMW", model: "M3", year: 2015, createdAt: base)
        try store.save(second)
        try store.save(first)
        XCTAssertEqual(try store.loadAll().map(\.model), ["M3", "MX-5"])
    }

    func testDeleteRemovesVehicle() throws {
        let vehicle = Vehicle(make: "Honda", model: "Civic", year: 2020)
        try store.save(vehicle)
        try store.delete(id: vehicle.id)
        XCTAssertEqual(try store.loadAll(), [])
    }

    func testUpdateOverwritesExisting() throws {
        var vehicle = Vehicle(make: "Ford", model: "Focus", year: 2018, createdAt: wholeSecondDate)
        try store.save(vehicle)
        vehicle.year = 2019
        try store.save(vehicle)
        XCTAssertEqual(try store.loadAll(), [vehicle])
    }
}
