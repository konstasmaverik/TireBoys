import Foundation

/// Decides whether a raw GPS fix is trustworthy enough to enter a drive.
/// Bad fixes (tunnel reflections, cold-start jumps, stale cached locations)
/// would otherwise inflate distance and fake absurd top speeds.
public struct GPSFilter: Sendable {
    /// Fixes with worse (larger) accuracy radius than this are dropped.
    public var maxHorizontalAccuracyMeters: Double
    /// If the position implied by two consecutive fixes requires moving faster
    /// than this, the new fix is a teleport artifact, not driving.
    public var maxPlausibleSpeedMetersPerSecond: Double

    public init(
        maxHorizontalAccuracyMeters: Double = 25,
        maxPlausibleSpeedMetersPerSecond: Double = 90 // 324 km/h
    ) {
        self.maxHorizontalAccuracyMeters = maxHorizontalAccuracyMeters
        self.maxPlausibleSpeedMetersPerSecond = maxPlausibleSpeedMetersPerSecond
    }

    public enum Rejection: Equatable, Sendable {
        case poorAccuracy
        case notNewerThanPrevious
        case implausibleJump
    }

    /// Returns nil when the point should be accepted.
    public func evaluate(_ point: RoutePoint, previous: RoutePoint?) -> Rejection? {
        guard point.horizontalAccuracyMeters >= 0,
              point.horizontalAccuracyMeters <= maxHorizontalAccuracyMeters
        else { return .poorAccuracy }

        guard let previous else { return nil }

        let elapsed = point.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return .notNewerThanPrevious }

        let impliedSpeed = GeoDistance.meters(from: previous, to: point) / elapsed
        guard impliedSpeed <= maxPlausibleSpeedMetersPerSecond else { return .implausibleJump }

        return nil
    }
}
