import Foundation

/// A completed, immutable drive as persisted to disk (and later synced to the backend).
public struct Drive: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var distanceMeters: Double
    public var topSpeedMetersPerSecond: Double
    public var points: [RoutePoint]
    /// Optional in the schema so drives recorded before the garage existed
    /// still decode; the app tags every new drive.
    public var vehicleID: UUID?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double,
        topSpeedMetersPerSecond: Double,
        points: [RoutePoint],
        vehicleID: UUID? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.topSpeedMetersPerSecond = topSpeedMetersPerSecond
        self.points = points
        self.vehicleID = vehicleID
    }

    public var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    public var averageSpeedMetersPerSecond: Double {
        duration > 0 ? distanceMeters / duration : 0
    }
}
