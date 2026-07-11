import Foundation

enum AppPaths {
    /// Where JSONDriveStore keeps recorded drives. Documents so the data
    /// survives app updates and (later) can be inspected via Files app.
    static var drivesDirectory: URL {
        URL.documentsDirectory.appending(path: "Drives", directoryHint: .isDirectory)
    }

    static var vehiclesDirectory: URL {
        URL.documentsDirectory.appending(path: "Vehicles", directoryHint: .isDirectory)
    }
}
