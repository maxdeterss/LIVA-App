import Foundation
import SwiftUI
import CoreLocation
import AVFoundation
import UIKit
import Observation

/// The live GPS tracking engine. Consumes a `LocationProvider`, filters jitter,
/// computes ~1 Hz live metrics, auto-pauses, marks splits (haptic + voice), and
/// continuously persists the in-progress track so a crash never loses it.
@MainActor
@Observable
final class ActivityRecorder {
    enum State: Equatable { case idle, recording, paused, finished }

    // Configuration
    var sport: WorkoutKind = .cardioRun
    var isIndoor = false
    var voiceEnabled = true
    var useImperial = true

    // Live state
    private(set) var state: State = .idle
    private(set) var startedAt: Date?
    private(set) var points: [TrackPoint] = []
    private(set) var splits: [Split] = []
    private(set) var autoPaused = false

    private(set) var distanceM: Double = 0
    private(set) var elapsedS: Double = 0
    private(set) var movingS: Double = 0
    private(set) var currentSpeedMps: Double = 0
    private(set) var maxSpeedMps: Double = 0
    private(set) var elevationGainM: Double = 0
    private(set) var elevationLossM: Double = 0
    var manualDistanceM: Double = 0   // indoor mode input

    var authorization: CLAuthorizationStatus = .notDetermined

    // Internals
    private let provider: LocationProvider
    private let synth = AVSpeechSynthesizer()
    private var ticker: Timer?
    private var pausedAccumulatedS: Double = 0
    private var pauseStartedAt: Date?
    private var lastPoint: TrackPoint?
    private var lastPersist = Date.distantPast
    private var spokenSplits = 0

    private var splitIntervalM: Double { useImperial ? 1609.344 : 1000 }
    private var moveThresholdMps: Double { 0.6 }
    private var autoPauseAfterS: Double { 8 }
    private var lastMovingAt: Date?

    init(provider: LocationProvider? = nil) {
        let resolved = provider ?? LocationProviderFactory.make()
        self.provider = resolved
        resolved.onUpdate = { [weak self] loc in self?.ingest(loc) }
        resolved.onAuthChange = { [weak self] status in self?.authorization = status }
        self.authorization = resolved.authorizationStatus
    }

    // MARK: Permissions

    func requestPermission() {
        provider.requestWhenInUseAuthorization()
    }

    var hasLocationPermission: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    // MARK: Lifecycle

    func start() {
        reset()
        state = .recording
        startedAt = Date()
        lastMovingAt = Date()
        if !isIndoor { provider.start(activityType: clActivityType) }
        startTicker()
    }

    func pause() {
        guard state == .recording else { return }
        state = .paused
        pauseStartedAt = Date()
        provider.stop()
    }

    func resume() {
        guard state == .paused else { return }
        if let p = pauseStartedAt { pausedAccumulatedS += Date().timeIntervalSince(p) }
        pauseStartedAt = nil
        state = .recording
        if !isIndoor { provider.start(activityType: clActivityType) }
    }

    /// Finalize and return a summary for the editor/save flow.
    func finish() -> ActivitySummaryDraft {
        state = .finished
        provider.stop()
        ticker?.invalidate(); ticker = nil
        clearSnapshot()
        let dist = isIndoor ? manualDistanceM : distanceM
        return ActivitySummaryDraft(
            sport: sport, startedAt: startedAt ?? Date(), points: points, splits: splits,
            distanceM: dist, movingTimeS: movingS, elapsedTimeS: elapsedS,
            elevationGainM: elevationGainM, elevationLossM: elevationLossM,
            maxSpeedMps: maxSpeedMps, isIndoor: isIndoor
        )
    }

    func discard() {
        state = .idle
        provider.stop()
        ticker?.invalidate(); ticker = nil
        clearSnapshot()
        reset()
    }

    // MARK: Ingest

    private func ingest(_ location: CLLocation) {
        guard state == .recording, !isIndoor else { return }
        let candidate = TrackPoint(location)
        guard GPSMath.shouldAccept(candidate, after: lastPoint, maxSpeedMps: speedCeiling) else { return }

        if let last = lastPoint {
            let dt = candidate.timestamp.timeIntervalSince(last.timestamp)
            let d = GPSMath.distance(last, candidate)
            let speed = dt > 0 ? d / dt : 0
            if speed >= moveThresholdMps {
                distanceM += d
                movingS += dt
                autoPaused = false
                lastMovingAt = candidate.timestamp
            } else if let lm = lastMovingAt, candidate.timestamp.timeIntervalSince(lm) > autoPauseAfterS {
                autoPaused = true
            }
            currentSpeedMps = location.speed >= 0 ? location.speed : speed
        }
        maxSpeedMps = max(maxSpeedMps, currentSpeedMps)
        points.append(candidate)
        lastPoint = candidate

        let elev = GPSMath.elevation(points)
        elevationGainM = elev.gain; elevationLossM = elev.loss

        updateSplits()
        persistThrottled()
    }

    private func updateSplits() {
        splits = GPSMath.splits(points, intervalM: splitIntervalM)
        if splits.count > spokenSplits {
            spokenSplits = splits.count
            announceSplit(splits.last!)
        }
    }

    private func announceSplit(_ split: Split) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard voiceEnabled else { return }
        let unit = useImperial ? "mile" : "kilometer"
        let pace = GPSMath.formatPace(secPerKm: split.paceSecPerKm, imperial: useImperial)
        let text = "\(unit) \(split.index). Average pace \(spoken(pace)) per \(unit)."
        speak(text)
    }

    private func speak(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(u)
    }

    private func spoken(_ pace: String) -> String {
        let parts = pace.split(separator: ":")
        guard parts.count == 2 else { return pace }
        return "\(parts[0]) \(Int(parts[1]) ?? 0) seconds"
    }

    // MARK: Timer

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard state == .recording, let start = startedAt else { return }
        elapsedS = Date().timeIntervalSince(start) - pausedAccumulatedS
        if isIndoor { movingS = elapsedS; distanceM = manualDistanceM }
    }

    // MARK: Derived

    var avgPaceSecPerKm: Double { GPSMath.paceSecPerKm(distanceM: displayDistanceM, seconds: movingS) ?? 0 }
    var currentPaceSecPerKm: Double {
        currentSpeedMps > 0.2 ? (1000 / currentSpeedMps) : 0
    }
    var displayDistanceM: Double { isIndoor ? manualDistanceM : distanceM }

    private var speedCeiling: Double {
        switch sport {
        case .cardioRide: return 25
        case .cardioRun, .cardioHike, .cardioWalk: return 12
        case .cardioSwim: return 4
        default: return 15
        }
    }

    private var clActivityType: CLActivityType {
        switch sport {
        case .cardioRide: return .otherNavigation
        case .cardioRun, .cardioWalk, .cardioHike: return .fitness
        default: return .fitness
        }
    }

    // MARK: Persistence (crash recovery)

    private static var snapshotURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("active_activity.json")
    }

    private func persistThrottled() {
        guard Date().timeIntervalSince(lastPersist) > 3 else { return }
        lastPersist = Date()
        let snap = ActivitySnapshot(sport: sport, startedAt: startedAt ?? Date(), points: points,
                                    movingTimeS: movingS, pausedTimeS: pausedAccumulatedS,
                                    isIndoor: isIndoor, manualDistanceM: manualDistanceM)
        if let data = try? AppJSON.encoder.encode(snap) {
            try? data.write(to: Self.snapshotURL, options: .atomic)
        }
    }

    private func clearSnapshot() { try? FileManager.default.removeItem(at: Self.snapshotURL) }

    /// Returns a recoverable snapshot left by a previous crash, if any.
    static func recoverable() -> ActivitySnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? AppJSON.decoder.decode(ActivitySnapshot.self, from: data)
    }

    /// Rehydrate from a recovered snapshot, paused so the user can resume or finish.
    func restore(from snapshot: ActivitySnapshot) {
        reset()
        sport = snapshot.sport
        startedAt = snapshot.startedAt
        points = snapshot.points
        isIndoor = snapshot.isIndoor
        manualDistanceM = snapshot.manualDistanceM
        movingS = snapshot.movingTimeS
        pausedAccumulatedS = snapshot.pausedTimeS
        lastPoint = points.last
        distanceM = GPSMath.totalDistance(points)
        let elev = GPSMath.elevation(points)
        elevationGainM = elev.gain; elevationLossM = elev.loss
        splits = GPSMath.splits(points, intervalM: splitIntervalM)
        spokenSplits = splits.count
        elapsedS = Date().timeIntervalSince(snapshot.startedAt) - pausedAccumulatedS
        state = .paused
        pauseStartedAt = Date()
    }

    func discardRecoverable() { clearSnapshot() }

    private func reset() {
        points = []; splits = []; distanceM = 0; elapsedS = 0; movingS = 0
        currentSpeedMps = 0; maxSpeedMps = 0; elevationGainM = 0; elevationLossM = 0
        pausedAccumulatedS = 0; pauseStartedAt = nil; lastPoint = nil; spokenSplits = 0
        autoPaused = false; lastMovingAt = nil
    }
}

/// Immutable summary handed to the post-activity editor/save flow.
struct ActivitySummaryDraft {
    var sport: WorkoutKind
    var startedAt: Date
    var points: [TrackPoint]
    var splits: [Split]
    var distanceM: Double
    var movingTimeS: Double
    var elapsedTimeS: Double
    var elevationGainM: Double
    var elevationLossM: Double
    var maxSpeedMps: Double
    var isIndoor: Bool

    var avgPaceSecPerKm: Double { GPSMath.paceSecPerKm(distanceM: distanceM, seconds: movingTimeS) ?? 0 }
    var avgSpeedMps: Double { movingTimeS > 0 ? distanceM / movingTimeS : 0 }
    var calories: Int {
        // Rough MET-based estimate; refined with HR on device.
        let minutes = movingTimeS / 60
        let met: Double = sport == .cardioRide ? 8 : sport == .cardioSwim ? 7 : 9.8
        return Int(met * 70 * minutes / 60)
    }
}
