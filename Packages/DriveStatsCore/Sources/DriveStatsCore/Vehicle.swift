import Foundation

/// A car in the user's garage. Drives are tagged with a vehicle id.
public struct Vehicle: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var make: String
    public var model: String
    public var year: Int
    /// The little icon representing the car in lists and pickers.
    public var emoji: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        emoji: String = "🚗",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.emoji = emoji
        self.createdAt = createdAt
    }

    /// Vehicles saved before icons existed lack the emoji key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        year = try container.decode(Int.self, forKey: .year)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🚗"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
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
