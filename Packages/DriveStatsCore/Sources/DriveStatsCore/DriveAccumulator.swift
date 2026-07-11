import Foundation

/// Live state of an in-progress recording. Feed it raw fixes; it filters them
/// and keeps running totals so the HUD can render without recomputing.
public struct DriveAccumulator: Sendable {
    public let startedAt: Date
    public private(set) var points: [RoutePoint] = []
    public private(set) var distanceMeters: Double = 0
    public private(set) var topSpeedMetersPerSecond: Double = 0

    private let filter: GPSFilter

    public init(startedAt: Date = Date(), filter: GPSFilter = GPSFilter()) {
        self.startedAt = startedAt
        self.filter = filter
    }

    /// Returns the rejection reason, or nil if the point was accepted.
    @discardableResult
    public mutating func add(_ point: RoutePoint) -> GPSFilter.Rejection? {
        if let rejection = filter.evaluate(point, previous: points.last) {
            return rejection
        }
        if let last = points.last {
            distanceMeters += GeoDistance.meters(from: last, to: point)
        }
        // Negative speed means "invalid fix" per CLLocation, so it never wins here.
        topSpeedMetersPerSecond = max(topSpeedMetersPerSecond, point.speedMetersPerSecond)
        points.append(point)
        return nil
    }

    public func finish(at endedAt: Date = Date()) -> Drive {
        Drive(
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            topSpeedMetersPerSecond: topSpeedMetersPerSecond,
            points: points
        )
    }
}
