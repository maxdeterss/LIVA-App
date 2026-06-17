import Foundation
import CoreLocation

/// A single recorded GPS sample.
struct TrackPoint: Codable, Hashable {
    var lat: Double
    var lng: Double
    var altitude: Double
    var timestamp: Date
    var horizontalAccuracy: Double
    var speed: Double          // m/s, -1 if unknown

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }

    init(lat: Double, lng: Double, altitude: Double = 0, timestamp: Date,
         horizontalAccuracy: Double = 5, speed: Double = -1) {
        self.lat = lat; self.lng = lng; self.altitude = altitude
        self.timestamp = timestamp; self.horizontalAccuracy = horizontalAccuracy; self.speed = speed
    }

    init(_ location: CLLocation) {
        lat = location.coordinate.latitude
        lng = location.coordinate.longitude
        altitude = location.altitude
        timestamp = location.timestamp
        horizontalAccuracy = location.horizontalAccuracy
        speed = location.speed
    }
}

/// A per-kilometer (or per-mile) split.
struct Split: Identifiable, Hashable {
    let id = UUID()
    var index: Int
    var distanceM: Double
    var durationS: Double
    var paceSecPerKm: Double
    var elevationGainM: Double
}

/// Persisted snapshot of an in-progress activity (crash recovery).
struct ActivitySnapshot: Codable {
    var sport: WorkoutKind
    var startedAt: Date
    var points: [TrackPoint]
    var movingTimeS: Double
    var pausedTimeS: Double
    var isIndoor: Bool
    var manualDistanceM: Double   // indoor mode
}

/// Gear (shoes/bike).
struct GearItem: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var userID: UUID? = nil
    var kind: String
    var name: String
    var brand: String?
    var distanceM: Double
    var retired: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, name, brand, retired
        case userID = "user_id"
        case distanceM = "distance_m"
    }
}

/// A detected personal record.
struct PersonalRecordItem: Codable, Identifiable, Hashable {
    var id: UUID? = nil
    var recordType: String
    var value: Double
    var achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, value
        case recordType = "record_type"
        case achievedAt = "achieved_at"
    }

    var title: String {
        switch recordType {
        case "fastest_1k": return "Fastest 1K"
        case "fastest_5k": return "Fastest 5K"
        case "fastest_10k": return "Fastest 10K"
        case "longest_run": return "Longest Distance"
        case "most_elevation": return "Most Elevation"
        default: return recordType
        }
    }
}
