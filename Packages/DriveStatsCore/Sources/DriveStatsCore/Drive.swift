import Foundation

/// A completed, immutable drive as persisted to disk (and later synced to the backend).
public struct Drive: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var distanceMeters: Double
    public var topSpeedMetersPerSecond: Double
    public var points: [RoutePoint]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double,
        topSpeedMetersPerSecond: Double,
        points: [RoutePoint]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.topSpeedMetersPerSecond = topSpeedMetersPerSecond
        self.points = points
    }

    public var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    public var averageSpeedMetersPerSecond: Double {
        duration > 0 ? distanceMeters / duration : 0
    }
}
