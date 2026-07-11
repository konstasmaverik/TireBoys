import Foundation

/// One accepted GPS fix. Mirrors the CLLocation fields the app needs, but stays
/// Foundation-only so filtering and accumulation are testable on Linux.
public struct RoutePoint: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    /// Meters per second. CLLocation convention: negative means "invalid".
    public var speedMetersPerSecond: Double
    /// Meters. CLLocation convention: negative means "invalid".
    public var horizontalAccuracyMeters: Double

    public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        speedMetersPerSecond: Double,
        horizontalAccuracyMeters: Double
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.speedMetersPerSecond = speedMetersPerSecond
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}
