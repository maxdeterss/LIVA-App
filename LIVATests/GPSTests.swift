import Testing
import Foundation
@testable import LIVA

private func line(count: Int, stepLng: Double = 0.001, dt: Double = 30) -> [TrackPoint] {
    let base = Date(timeIntervalSince1970: 0)
    return (0..<count).map { i in
        TrackPoint(lat: 0, lng: Double(i) * stepLng, altitude: 0,
                   timestamp: base.addingTimeInterval(Double(i) * dt),
                   horizontalAccuracy: 5, speed: 3.7)
    }
}

struct GPSMathTests {

    @Test func haversineKnownDistance() {
        // 0.001° of longitude at the equator ≈ 111.32 m
        let d = GPSMath.haversine(0, 0, 0, 0.001)
        #expect(abs(d - 111.32) < 1.0)
    }

    @Test func totalDistanceAccumulates() {
        let pts = line(count: 11)             // 10 hops × ~111.32 m
        let d = GPSMath.totalDistance(pts)
        #expect(abs(d - 1113.2) < 10)
    }

    @Test func elevationGainAndLossWithThreshold() {
        let base = Date(timeIntervalSince1970: 0)
        let pts = [0.0, 5, 4.5, 10, 9].enumerated().map { i, alt in
            TrackPoint(lat: 0, lng: Double(i) * 0.001, altitude: alt,
                       timestamp: base.addingTimeInterval(Double(i)), horizontalAccuracy: 5)
        }
        let e = GPSMath.elevation(pts, threshold: 1.0)
        // +5, (-0.5 ignored), +5.5, (-1.0 not > threshold) => gain 10.5
        #expect(abs(e.gain - 10.5) < 0.001)
        #expect(e.loss == 0)
    }

    @Test func paceFormatting() {
        // 5:00 / km
        #expect(GPSMath.formatPace(secPerKm: 300, imperial: false) == "5:00")
        #expect(GPSMath.formatDuration(3661) == "1:01:01")
        #expect(GPSMath.formatDuration(125) == "2:05")
    }

    @Test func filterRejectsPoorAccuracyAndTeleports() {
        let base = Date(timeIntervalSince1970: 0)
        let good = TrackPoint(lat: 0, lng: 0, timestamp: base, horizontalAccuracy: 5)
        let inaccurate = TrackPoint(lat: 0, lng: 0.001, timestamp: base.addingTimeInterval(1), horizontalAccuracy: 80)
        #expect(GPSMath.shouldAccept(inaccurate, after: good) == false)

        // ~111 km jump in 1s → impossible
        let teleport = TrackPoint(lat: 1, lng: 0, timestamp: base.addingTimeInterval(1), horizontalAccuracy: 5)
        #expect(GPSMath.shouldAccept(teleport, after: good) == false)

        let normal = TrackPoint(lat: 0, lng: 0.0001, timestamp: base.addingTimeInterval(5), horizontalAccuracy: 5)
        #expect(GPSMath.shouldAccept(normal, after: good) == true)
    }

    @Test func splitsAreMarkedPerInterval() {
        let pts = line(count: 30)            // ~3.2 km total
        let splits = GPSMath.splits(pts, intervalM: 1000)
        #expect(splits.count >= 2)
        #expect(abs(splits[0].distanceM - 1000) < 1)
        #expect(splits[0].paceSecPerKm > 0)
    }
}

struct PolylineTests {
    @Test func roundTrips() {
        let coords = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]
        let encoded = Polyline.encode(coords.map { (lat: $0.0, lng: $0.1) })
        let decoded = Polyline.decode(encoded)
        #expect(decoded.count == coords.count)
        for (a, b) in zip(decoded, coords) {
            #expect(abs(a.lat - b.0) < 1e-5)
            #expect(abs(a.lng - b.1) < 1e-5)
        }
    }

    @Test func matchesKnownGoogleEncoding() {
        let coords = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]
        #expect(Polyline.encode(coords.map { (lat: $0.0, lng: $0.1) }) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    }
}

struct PRDetectionTests {
    @Test func fastestDurationOverWindow() {
        let pts = line(count: 30, stepLng: 0.001, dt: 30)   // ~111 m / 30 s steps
        let t = PRDetection.fastestDuration(points: pts, distanceM: 1000)
        #expect(t != nil)
        // ~9 hops to reach 1 km → ~270 s
        #expect(abs((t ?? 0) - 270) < 35)
    }

    @Test func fastestDurationNilWhenRouteTooShort() {
        let pts = line(count: 5)            // ~445 m
        #expect(PRDetection.fastestDuration(points: pts, distanceM: 1000) == nil)
    }

    @Test func improvementDirection() {
        #expect(PRDetection.isImprovement(type: "fastest_5k", candidate: 1400, existing: 1500))
        #expect(PRDetection.isImprovement(type: "fastest_5k", candidate: 1600, existing: 1500) == false)
        #expect(PRDetection.isImprovement(type: "longest_run", candidate: 10000, existing: 8000))
        #expect(PRDetection.isImprovement(type: "most_elevation", candidate: 100, existing: nil))
    }
}
