import CoreLocation

/// Thin wrapper around CLLocationManager. All CoreLocation stays here so the
/// rest of the app (and DriveStatsCore) never imports it.
///
/// Main-actor bound: CLLocationManager is created on the main thread, so its
/// delegate callbacks also arrive there, and the consuming view model is
/// main-actor isolated anyway.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onLocation: (@MainActor (CLLocation) -> Void)?
    var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Needed for auto-detection: starting precise updates from the background
    /// (when motion activity says a drive began) requires Always authorization.
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    /// Significant-change monitoring keeps the app being woken while it waits
    /// for a drive to start; it survives suspension and even termination.
    func startMonitoringSignificantChanges() {
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopMonitoringSignificantChanges() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    func startUpdates() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        // Keeps recording alive when the phone is locked in a mount. Requires
        // the "location" UIBackgroundModes entry and a session started in the
        // foreground; works with When-In-Use authorization.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    // MARK: - CLLocationManagerDelegate

    // The protocol's requirements are nonisolated, but the manager is created on
    // the main thread so callbacks arrive there — assumeIsolated makes that
    // contract explicit instead of tripping Swift 6 conformance checking.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            for location in locations {
                onLocation?(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient GPS dropouts (kCLErrorLocationUnknown) resolve on their own;
        // the filter in DriveStatsCore handles any garbage that still arrives.
    }
}
