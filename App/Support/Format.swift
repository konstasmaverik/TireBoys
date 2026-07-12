import DriveStatsCore
import Foundation

enum Format {
    static let useMilesKey = "useMiles"

    private static var useMiles: Bool {
        UserDefaults.standard.bool(forKey: useMilesKey)
    }

    /// Number only — pair with `speedUnit` for the label.
    static func speed(_ metersPerSecond: Double) -> String {
        let clamped = max(0, metersPerSecond)
        let value = useMiles
            ? UnitConversion.milesPerHour(fromMetersPerSecond: clamped)
            : UnitConversion.kilometersPerHour(fromMetersPerSecond: clamped)
        return String(format: "%.0f", value)
    }

    static var speedUnit: String {
        useMiles ? "mph" : "km/h"
    }

    static func speedWithUnit(_ metersPerSecond: Double) -> String {
        "\(speed(metersPerSecond)) \(speedUnit)"
    }

    static func distance(_ meters: Double) -> String {
        useMiles
            ? String(format: "%.1f mi", UnitConversion.miles(fromMeters: meters))
            : String(format: "%.1f km", UnitConversion.kilometers(fromMeters: meters))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds))
            .formatted(.time(pattern: .hourMinuteSecond))
    }
}
