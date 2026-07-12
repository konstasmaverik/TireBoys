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

    let isAutoDetectSupported = MotionActivityService.isAvailable

    var isAutoDetectEnabled = false {
        didSet {
            guard oldValue != isAutoDetectEnabled else { return }
            UserDefaults.standard.set(isAutoDetectEnabled, forKey: Self.autoDetectKey)
            applyAutoDetectState()
        }
    }

    /// Supplies the vehicle to tag a finishing drive with (the garage's
    /// active vehicle). A closure so background auto-stops get the current
    /// value without this model owning garage state.
    var vehicleIDProvider: (@MainActor () -> UUID?)?

    /// Fired after a drive is persisted; the app uses it to trigger backend sync.
    var onDriveSaved: (@MainActor () -> Void)?

    private let locationService: LocationService
    private let motionService: MotionActivityService
    private let store: JSONDriveStore?
    private var policy = DriveDetectionPolicy()
    private var tickTimer: Timer?

    private static let autoDetectKey = "autoDetectEnabled"

    init(locationService: LocationService? = nil, motionService: MotionActivityService? = nil) {
        self.locationService = locationService ?? LocationService()
        self.motionService = motionService ?? MotionActivityService()
        store = try? JSONDriveStore(directory: AppPaths.drivesDirectory)

        self.locationService.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
        self.locationService.onLocation = { [weak self] location in
            self?.ingest(location)
        }
        self.motionService.onSample = { [weak self] sample in
            self?.handleMotionSample(sample)
        }

        // didSet observers don't run during init, so re-arm explicitly. This
        // also covers iOS relaunching the app in the background after a
        // significant-change wake: the App owns this model, so init runs there.
        isAutoDetectEnabled = UserDefaults.standard.bool(forKey: Self.autoDetectKey)
        if isAutoDetectEnabled {
            applyAutoDetectState()
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
        policy.syncRecordingState(isRecording: true)
        updateTickTimer()
    }

    func stopDrive() {
        guard isRecording else { return }
        locationService.stopUpdates()
        isRecording = false
        currentSpeedMetersPerSecond = 0
        policy.syncRecordingState(isRecording: false)
        updateTickTimer()

        guard let finished = accumulator, !finished.points.isEmpty else {
            accumulator = nil
            return
        }
        do {
            guard let store else { throw CocoaError(.fileWriteUnknown) }
            try store.save(finished.finish(vehicleID: vehicleIDProvider?()))
            onDriveSaved?()
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

    // MARK: - Automatic drive detection

    private func applyAutoDetectState() {
        if isAutoDetectEnabled {
            locationService.requestAlwaysAuthorization()
            locationService.startMonitoringSignificantChanges()
            motionService.startUpdates()
        } else {
            motionService.stopUpdates()
            locationService.stopMonitoringSignificantChanges()
            policy.syncRecordingState(isRecording: isRecording)
        }
        updateTickTimer()
    }

    private func handleMotionSample(_ sample: MotionSample) {
        guard isAutoDetectEnabled else { return }
        apply(policy.ingest(sample))
        updateTickTimer()
    }

    private func handleTick() {
        apply(policy.tick(at: Date()))
        updateTickTimer()
    }

    private func apply(_ decision: DriveDetectionPolicy.Decision?) {
        switch decision {
        case .startDrive:
            startDrive()
            if !isRecording {
                // startDrive refused (authorization lost); keep policy honest
                // so it can decide to start again later.
                policy.syncRecordingState(isRecording: false)
            }
        case .stopDrive:
            stopDrive()
        case nil:
            break
        }
    }

    /// CoreMotion only reports activity *changes*, so a pending candidate
    /// transition usually crosses its threshold with no new sample arriving —
    /// the timer re-evaluates the policy against the clock.
    private func updateTickTimer() {
        if isAutoDetectEnabled, policy.candidateSince != nil {
            guard tickTimer == nil else { return }
            tickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleTick()
                }
            }
        } else {
            tickTimer?.invalidate()
            tickTimer = nil
        }
    }
}
