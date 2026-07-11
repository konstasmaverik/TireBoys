import CoreLocation
import DriveStatsCore
import Foundation
import Observation

@MainActor
@Observable
final class RecordingViewModel {
    private(set) var isRecording = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Clamped to 0 for display; CLLocation reports -1 while GPS has no fix.
    private(set) var currentSpeedMetersPerSecond: Double = 0
    private(set) var accumulator: DriveAccumulator?
    private(set) var saveError: String?

    private let locationService: LocationService
    private let store: JSONDriveStore?

    init(locationService: LocationService? = nil) {
        self.locationService = locationService ?? LocationService()
        store = try? JSONDriveStore(directory: AppPaths.drivesDirectory)

        self.locationService.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
        self.locationService.onLocation = { [weak self] location in
            self?.ingest(location)
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestPermission() {
        locationService.requestWhenInUseAuthorization()
    }

    func startDrive() {
        guard !isRecording, isAuthorized else { return }
        saveError = nil
        accumulator = DriveAccumulator()
        currentSpeedMetersPerSecond = 0
        isRecording = true
        locationService.startUpdates()
    }

    func stopDrive() {
        guard isRecording else { return }
        locationService.stopUpdates()
        isRecording = false
        currentSpeedMetersPerSecond = 0

        guard let finished = accumulator, !finished.points.isEmpty else {
            accumulator = nil
            return
        }
        do {
            guard let store else { throw CocoaError(.fileWriteUnknown) }
            try store.save(finished.finish())
        } catch {
            saveError = "Could not save drive: \(error.localizedDescription)"
        }
        accumulator = nil
    }

    private func ingest(_ location: CLLocation) {
        guard isRecording else { return }
        currentSpeedMetersPerSecond = max(0, location.speed)
        accumulator?.add(
            RoutePoint(
                timestamp: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                speedMetersPerSecond: location.speed,
                horizontalAccuracyMeters: location.horizontalAccuracy
            )
        )
    }
}
