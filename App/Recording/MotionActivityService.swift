import CoreMotion
import DriveStatsCore

/// Thin wrapper around CMMotionActivityManager. All CoreMotion stays here so
/// the rest of the app (and DriveStatsCore) never imports it.
@MainActor
final class MotionActivityService {
    private let manager = CMMotionActivityManager()

    var onSample: (@MainActor (MotionSample) -> Void)?

    static var isAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    func startUpdates() {
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            let sample = MotionSample(
                timestamp: activity.startDate,
                isAutomotive: activity.automotive,
                confidence: MotionConfidence(activity.confidence)
            )
            MainActor.assumeIsolated {
                self?.onSample?(sample)
            }
        }
    }

    func stopUpdates() {
        manager.stopActivityUpdates()
    }
}

private extension MotionConfidence {
    init(_ confidence: CMMotionActivityConfidence) {
        switch confidence {
        case .low: self = .low
        case .medium: self = .medium
        case .high: self = .high
        @unknown default: self = .low
        }
    }
}
