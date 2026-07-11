import XCTest
@testable import DriveStatsCore

final class GeoDistanceTests: XCTestCase {
    func testZeroDistanceForSamePoint() {
        XCTAssertEqual(
            GeoDistance.meters(fromLatitude: 37.9838, longitude: 23.7275,
                               toLatitude: 37.9838, longitude: 23.7275),
            0, accuracy: 0.001
        )
    }

    func testKnownCityPairDistance() {
        // Athens (37.9838, 23.7275) to Thessaloniki (40.6401, 22.9444) ≈ 300 km.
        let meters = GeoDistance.meters(
            fromLatitude: 37.9838, longitude: 23.7275,
            toLatitude: 40.6401, longitude: 22.9444
        )
        XCTAssertEqual(meters, 302_000, accuracy: 5_000)
    }

    func testShortDistanceMatchesLatitudeDegreeLength() {
        // 0.001° of latitude ≈ 111.2 m everywhere on the sphere.
        let meters = GeoDistance.meters(
            fromLatitude: 37.0, longitude: 23.0,
            toLatitude: 37.001, longitude: 23.0
        )
        XCTAssertEqual(meters, 111.2, accuracy: 0.5)
    }
}
