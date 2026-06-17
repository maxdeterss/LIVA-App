import Foundation

/// Pure GPS computations — distance, elevation, pace, splits, and the
/// jitter/teleport filter. No I/O, fully unit-testable.
enum GPSMath {
    static let earthRadiusM = 6_371_000.0

    /// Great-circle distance between two coordinates, in meters (haversine).
    static func haversine(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    static func distance(_ a: TrackPoint, _ b: TrackPoint) -> Double {
        haversine(a.lat, a.lng, b.lat, b.lng)
    }

    /// Total path distance over a sequence of points (meters).
    static func totalDistance(_ points: [TrackPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    /// Cumulative elevation gain/loss with a noise threshold (meters).
    static func elevation(_ points: [TrackPoint], threshold: Double = 1.0) -> (gain: Double, loss: Double) {
        guard points.count > 1 else { return (0, 0) }
        var gain = 0.0, loss = 0.0
        for (a, b) in zip(points, points.dropFirst()) {
            let d = b.altitude - a.altitude
            if d > threshold { gain += d }
            else if d < -threshold { loss += -d }
        }
        return (gain, loss)
    }

    /// Pace in seconds per kilometer.
    static func paceSecPerKm(distanceM: Double, seconds: Double) -> Double? {
        guard distanceM > 0, seconds > 0 else { return nil }
        return seconds / (distanceM / 1000)
    }

    static func formatPace(secPerKm: Double, imperial: Bool) -> String {
        let perUnit = imperial ? secPerKm * 1.609344 : secPerKm
        guard perUnit.isFinite, perUnit > 0 else { return "--:--" }
        let t = Int(perUnit.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    static func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// Whether to accept a new point given the previous accepted one.
    /// Rejects poor-accuracy fixes and impossible "teleport" jumps.
    static func shouldAccept(_ candidate: TrackPoint, after previous: TrackPoint?,
                             maxAccuracy: Double = 30, maxSpeedMps: Double = 12) -> Bool {
        guard candidate.horizontalAccuracy >= 0, candidate.horizontalAccuracy <= maxAccuracy else { return false }
        guard let previous else { return true }
        let dt = candidate.timestamp.timeIntervalSince(previous.timestamp)
        guard dt > 0 else { return false }
        let d = distance(previous, candidate)
        // Reject teleports: implied speed beyond a generous sport ceiling.
        return d / dt <= maxSpeedMps
    }

    /// Builds per-interval splits (interval in meters, e.g. 1000 for km).
    static func splits(_ points: [TrackPoint], intervalM: Double) -> [Split] {
        guard points.count > 1, intervalM > 0 else { return [] }
        var result: [Split] = []
        var cumulative = 0.0
        var splitStartDist = 0.0
        var splitStartTime = points[0].timestamp
        var splitStartAlt = points[0].altitude
        var index = 1

        for (a, b) in zip(points, points.dropFirst()) {
            cumulative += distance(a, b)
            while cumulative >= Double(index) * intervalM {
                let dur = b.timestamp.timeIntervalSince(splitStartTime)
                let dist = Double(index) * intervalM - splitStartDist
                result.append(Split(
                    index: index, distanceM: dist, durationS: dur,
                    paceSecPerKm: paceSecPerKm(distanceM: dist, seconds: dur) ?? 0,
                    elevationGainM: max(0, b.altitude - splitStartAlt)
                ))
                splitStartDist = Double(index) * intervalM
                splitStartTime = b.timestamp
                splitStartAlt = b.altitude
                index += 1
            }
        }
        return result
    }

    /// Bounding box for a route.
    static func bounds(_ points: [TrackPoint]) -> [String: Double]? {
        guard let first = points.first else { return nil }
        var minLat = first.lat, maxLat = first.lat, minLng = first.lng, maxLng = first.lng
        for p in points {
            minLat = min(minLat, p.lat); maxLat = max(maxLat, p.lat)
            minLng = min(minLng, p.lng); maxLng = max(maxLng, p.lng)
        }
        return ["minLat": minLat, "maxLat": maxLat, "minLng": minLng, "maxLng": maxLng]
    }
}
