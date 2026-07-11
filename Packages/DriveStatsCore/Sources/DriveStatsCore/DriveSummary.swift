import Foundation

/// Aggregated personal stats over a set of drives. Pure computation so the
/// stats screen (and later, leaderboard uploads) share one definition.
public struct DriveSummary: Equatable, Sendable {
    public var driveCount: Int
    public var totalDistanceMeters: Double
    public var totalDuration: TimeInterval
    public var topSpeedMetersPerSecond: Double
    public var longestDriveMeters: Double

    public static let empty = DriveSummary(
        driveCount: 0,
        totalDistanceMeters: 0,
        totalDuration: 0,
        topSpeedMetersPerSecond: 0,
        longestDriveMeters: 0
    )

    public init(
        driveCount: Int,
        totalDistanceMeters: Double,
        totalDuration: TimeInterval,
        topSpeedMetersPerSecond: Double,
        longestDriveMeters: Double
    ) {
        self.driveCount = driveCount
        self.totalDistanceMeters = totalDistanceMeters
        self.totalDuration = totalDuration
        self.topSpeedMetersPerSecond = topSpeedMetersPerSecond
        self.longestDriveMeters = longestDriveMeters
    }

    /// Drives can be pre-filtered by period or vehicle before calling.
    public static func compute(from drives: [Drive]) -> DriveSummary {
        drives.reduce(into: .empty) { summary, drive in
            summary.driveCount += 1
            summary.totalDistanceMeters += drive.distanceMeters
            summary.totalDuration += drive.duration
            summary.topSpeedMetersPerSecond = max(summary.topSpeedMetersPerSecond, drive.topSpeedMetersPerSecond)
            summary.longestDriveMeters = max(summary.longestDriveMeters, drive.distanceMeters)
        }
    }
}
