// swift-tools-version:5.9
import PackageDescription

// Pure-logic package: no UIKit/SwiftUI/CoreLocation imports allowed here,
// so it stays testable on Linux CI runners (the only fast test path while
// development happens without a Mac).
let package = Package(
    name: "DriveStatsCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DriveStatsCore", targets: ["DriveStatsCore"]),
    ],
    targets: [
        .target(name: "DriveStatsCore"),
        .testTarget(name: "DriveStatsCoreTests", dependencies: ["DriveStatsCore"]),
    ]
)
