import XCTest
@testable import DriveStatsCore

final class DriveDetectionPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(
        secondsAfterStart: TimeInterval,
        automotive: Bool,
        confidence: MotionConfidence = .high
    ) -> MotionSample {
        MotionSample(
            timestamp: start.addingTimeInterval(secondsAfterStart),
            isAutomotive: automotive,
            confidence: confidence
        )
    }

    func testStartsAfterSustainedAutomotive() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: true)))
        XCTAssertEqual(policy.tick(at: start.addingTimeInterval(30)), .startDrive)
        XCTAssertTrue(policy.isDriving)
    }

    func testBriefAutomotiveBlipDoesNotStart() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: true)))
        // Walking again 10 s later cancels the candidate…
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 10, automotive: false)))
        // …so the original threshold passing means nothing.
        XCTAssertNil(policy.tick(at: start.addingTimeInterval(60)))
        XCTAssertFalse(policy.isDriving)
    }

    func testLowConfidenceSamplesAreIgnored() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: true)))
        // A low-confidence "walking" blip must not cancel the candidate.
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 10, automotive: false, confidence: .low)))
        XCTAssertEqual(policy.tick(at: start.addingTimeInterval(30)), .startDrive)
    }

    func testStopsAfterSustainedNonAutomotive() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        policy.syncRecordingState(isRecording: true)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: false)))
        XCTAssertEqual(policy.tick(at: start.addingTimeInterval(180)), .stopDrive)
        XCTAssertFalse(policy.isDriving)
    }

    func testTrafficStopDoesNotEndDrive() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        policy.syncRecordingState(isRecording: true)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: false)))
        // Moving again before the stop threshold cancels the candidate.
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 90, automotive: true)))
        XCTAssertNil(policy.tick(at: start.addingTimeInterval(300)))
        XCTAssertTrue(policy.isDriving)
    }

    func testDecisionFiresOnIngestWhenSampleArrivesLate() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: true)))
        // No tick needed if a confirming sample itself lands past the threshold.
        XCTAssertEqual(policy.ingest(sample(secondsAfterStart: 45, automotive: true)), .startDrive)
    }

    func testManualStopCancelsPendingStopCandidate() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        policy.syncRecordingState(isRecording: true)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: false)))
        // User hits Stop themselves; the pending auto-stop must not fire later.
        policy.syncRecordingState(isRecording: false)
        XCTAssertNil(policy.tick(at: start.addingTimeInterval(400)))
        XCTAssertFalse(policy.isDriving)
    }

    func testFullDriveCycle() {
        var policy = DriveDetectionPolicy(startAfterSeconds: 30, stopAfterSeconds: 180)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 0, automotive: true)))
        XCTAssertEqual(policy.tick(at: start.addingTimeInterval(35)), .startDrive)
        XCTAssertNil(policy.ingest(sample(secondsAfterStart: 600, automotive: false)))
        XCTAssertEqual(policy.tick(at: start.addingTimeInterval(600 + 180)), .stopDrive)
        XCTAssertFalse(policy.isDriving)
    }
}
