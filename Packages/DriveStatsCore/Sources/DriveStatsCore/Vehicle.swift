import Foundation

/// A car in the user's garage. Drives are tagged with a vehicle id.
public struct Vehicle: Codable, Equatable, Identifiable, Sendable {
    /// Which little icon represents the car. Cases map to glyphs app-side.
    public enum BodyStyle: String, Codable, CaseIterable, Sendable {
        case sedan, suv, sports, pickup
    }

    public var id: UUID
    public var make: String
    public var model: String
    public var year: Int
    public var bodyStyle: BodyStyle
    /// Paint color as #RRGGBB, rendered app-side.
    public var colorHex: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        bodyStyle: BodyStyle = .sedan,
        colorHex: String = "#D0312D",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.bodyStyle = bodyStyle
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    /// Vehicles saved before icons existed lack these keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        year = try container.decode(Int.self, forKey: .year)
        bodyStyle = try container.decodeIfPresent(BodyStyle.self, forKey: .bodyStyle) ?? .sedan
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#D0312D"
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
