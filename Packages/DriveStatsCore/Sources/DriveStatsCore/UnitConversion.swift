public enum UnitConversion {
    /// CoreLocation reports speed in meters per second; the product displays km/h.
    /// Sign-preserving: CLLocation uses -1 to mean "invalid speed" and callers
    /// must be able to detect that after conversion.
    public static func kilometersPerHour(fromMetersPerSecond metersPerSecond: Double) -> Double {
        metersPerSecond * 3.6
    }

    public static func kilometers(fromMeters meters: Double) -> Double {
        meters / 1000
    }

    /// Sign-preserving, like kilometersPerHour.
    public static func milesPerHour(fromMetersPerSecond metersPerSecond: Double) -> Double {
        metersPerSecond * 2.236936
    }

    public static func miles(fromMeters meters: Double) -> Double {
        meters / 1609.344
    }
}
