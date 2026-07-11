import Foundation

/// A car in the user's garage. Drives are tagged with a vehicle id.
public struct Vehicle: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var make: String
    public var model: String
    public var year: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), make: String, model: String, year: Int, createdAt: Date = Date()) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.createdAt = createdAt
    }

    public var displayName: String {
        "\(make) \(model) '\(String(year).suffix(2))"
    }
}

/// Vehicle persistence, oldest first (stable garage order).
public struct JSONVehicleStore: Sendable {
    private let store: JSONObjectStore<Vehicle>

    public init(directory: URL) throws {
        store = try JSONObjectStore(directory: directory)
    }

    public func save(_ vehicle: Vehicle) throws {
        try store.save(vehicle)
    }

    public func loadAll() throws -> [Vehicle] {
        try store.loadAll().sorted { $0.createdAt < $1.createdAt }
    }

    public func delete(id: UUID) throws {
        try store.delete(id: id)
    }
}
