import DriveStatsCore
import Foundation

enum Format {
    static func kilometersPerHour(_ metersPerSecond: Double) -> String {
        String(format: "%.0f", UnitConversion.kilometersPerHour(fromMetersPerSecond: max(0, metersPerSecond)))
    }

    static func kilometers(_ meters: Double) -> String {
        String(format: "%.1f km", UnitConversion.kilometers(fromMeters: meters))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds))
            .formatted(.time(pattern: .hourMinuteSecond))
    }
}
