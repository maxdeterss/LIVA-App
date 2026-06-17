import Foundation

/// Pure personal-record detection over a finished track. Unit-tested.
enum PRDetection {

    struct Candidate: Equatable { var type: String; var value: Double }

    /// Fastest contiguous time (seconds) to cover at least `distanceM`, via a
    /// two-pointer sliding window. Returns nil if the route is shorter.
    static func fastestDuration(points: [TrackPoint], distanceM: Double) -> Double? {
        guard points.count > 1, distanceM > 0 else { return nil }
        // Prefix distances/times
        var dist = [0.0], time = [0.0]
        for (a, b) in zip(points, points.dropFirst()) {
            dist.append(dist.last! + GPSMath.distance(a, b))
            time.append(time.last! + b.timestamp.timeIntervalSince(a.timestamp))
        }
        guard dist.last! >= distanceM else { return nil }
        var best = Double.infinity
        var j = 0
        for i in 0..<dist.count {
            if j < i { j = i }
            while j < dist.count && dist[j] - dist[i] < distanceM { j += 1 }
            if j < dist.count {
                best = min(best, time[j] - time[i])
            }
        }
        return best.isFinite ? best : nil
    }

    /// All record candidates this activity establishes (unfiltered by history).
    static func candidates(draft: ActivitySummaryDraft) -> [Candidate] {
        var out: [Candidate] = []
        if let t = fastestDuration(points: draft.points, distanceM: 1000) {
            out.append(.init(type: "fastest_1k", value: t))
        }
        if let t = fastestDuration(points: draft.points, distanceM: 5000) {
            out.append(.init(type: "fastest_5k", value: t))
        }
        if let t = fastestDuration(points: draft.points, distanceM: 10000) {
            out.append(.init(type: "fastest_10k", value: t))
        }
        out.append(.init(type: "longest_run", value: draft.distanceM))
        out.append(.init(type: "most_elevation", value: draft.elevationGainM))
        return out
    }

    /// Lower-is-better for pace records; higher-is-better otherwise.
    static func isImprovement(type: String, candidate: Double, existing: Double?) -> Bool {
        guard let existing else { return true }
        return type.hasPrefix("fastest_") ? candidate < existing : candidate > existing
    }
}
