import Foundation

public enum GeoDistance {
    /// Haversine great-circle distance in meters. Accurate to ~0.5% versus the
    /// WGS-84 ellipsoid, which is well inside GPS noise for drive tracking.
    public static func meters(
        fromLatitude lat1: Double, longitude lon1: Double,
        toLatitude lat2: Double, longitude lon2: Double
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let deltaPhi = (lat2 - lat1) * .pi / 180
        let deltaLambda = (lon2 - lon1) * .pi / 180

        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    public static func meters(from a: RoutePoint, to b: RoutePoint) -> Double {
        meters(
            fromLatitude: a.latitude, longitude: a.longitude,
            toLatitude: b.latitude, longitude: b.longitude
        )
    }
}
