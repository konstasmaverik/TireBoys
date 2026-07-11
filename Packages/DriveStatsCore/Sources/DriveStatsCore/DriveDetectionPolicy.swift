import Foundation

/// One motion-activity classification. Mirrors the CMMotionActivity fields the
/// app needs, but stays Foundation-only so detection logic is testable on Linux.
public struct MotionSample: Equatable, Sendable {
    public var timestamp: Date
    public var isAutomotive: Bool
    public var confidence: MotionConfidence

    public init(timestamp: Date, isAutomotive: Bool, confidence: MotionConfidence) {
        self.timestamp = timestamp
        self.isAutomotive = isAutomotive
        self.confidence = confidence
    }
}

/// CMMotionActivityConfidence, mirrored to keep CoreMotion out of this package.
public enum MotionConfidence: Comparable, Sendable {
    case low, medium, high
}

/// Decides when motion activity means a drive has started or ended. Both
/// transitions require the new activity to be *sustained*: a brief automotive
/// misclassification while walking must not start a recording, and a red
/// light or fuel stop must not end one.
public struct DriveDetectionPolicy: Sendable {
    public enum Decision: Equatable, Sendable {
        case startDrive
        case stopDrive
    }

    /// Automotive activity must persist this long before a drive starts.
    public var startAfterSeconds: TimeInterval
    /// Non-automotive activity must persist this long before a drive ends.
    public var stopAfterSeconds: TimeInterval

    public private(set) var isDriving = false
    /// When the current candidate transition (start or stop) began, if any.
    /// CoreMotion only reports activity *changes*, so the caller must also
    /// `tick(at:)` periodically while this is non-nil — the threshold usually
    /// elapses with no new sample to deliver the decision.
    public private(set) var candidateSince: Date?

    public init(startAfterSeconds: TimeInterval = 30, stopAfterSeconds: TimeInterval = 180) {
        self.startAfterSeconds = startAfterSeconds
        self.stopAfterSeconds = stopAfterSeconds
    }

    /// Call when recording is started or stopped outside the policy (manual
    /// button) so automatic decisions stay consistent with reality.
    public mutating func syncRecordingState(isRecording: Bool) {
        isDriving = isRecording
        candidateSince = nil
    }

    @discardableResult
    public mutating func ingest(_ sample: MotionSample) -> Decision? {
        // Low-confidence samples are noise: they neither begin nor cancel a
        // candidate transition.
        guard sample.confidence > .low else { return nil }

        if sample.isAutomotive == isDriving {
            candidateSince = nil
        } else if candidateSince == nil {
            candidateSince = sample.timestamp
        }
        return decision(at: sample.timestamp)
    }

    /// Re-evaluates the pending candidate against the clock.
    @discardableResult
    public mutating func tick(at date: Date) -> Decision? {
        decision(at: date)
    }

    private mutating func decision(at date: Date) -> Decision? {
        guard let since = candidateSince,
              date.timeIntervalSince(since) >= (isDriving ? stopAfterSeconds : startAfterSeconds)
        else { return nil }

        isDriving.toggle()
        candidateSince = nil
        return isDriving ? .startDrive : .stopDrive
    }
}
