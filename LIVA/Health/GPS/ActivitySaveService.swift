import Foundation
import MapKit
import Supabase

/// Persists a finished GPS activity: the workout row (+ GPS fields & encoded
/// polyline), the raw streams, detected PRs, and an optional share to the feed.
struct ActivitySaveService {
    let writer: RemoteWriter

    struct SaveResult {
        var workoutID: UUID
        var newRecords: [PersonalRecordItem]
    }

    func save(
        draft: ActivitySummaryDraft,
        title: String,
        notes: String?,
        privacy: Privacy,
        gearID: UUID?
    ) async throws -> SaveResult {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }

        let coords = draft.points.map { (lat: $0.lat, lng: $0.lng) }
        let polyline = Polyline.encode(coords)
        let bounds = GPSMath.bounds(draft.points)
        let iso = ISO8601DateFormatter()

        struct Row: Encodable, Sendable {
            let user_id: String; let type: String; let source: String; let title: String
            let started_at: String; let ended_at: String; let duration_s: Int
            let total_calories: Int; let privacy: String; let is_indoor: Bool
            let distance_m: Double; let moving_time_s: Int; let elapsed_time_s: Int
            let elevation_gain_m: Double; let elevation_loss_m: Double
            let avg_pace_s_per_km: Double; let avg_speed_mps: Double; let max_speed_mps: Double
            let polyline: String?; let bounds: [String: Double]?
            let start_lat: Double?; let start_lng: Double?; let end_lat: Double?; let end_lng: Double?
            let notes: String?; let gear_id: String?
        }
        let row = Row(
            user_id: uid.uuidString, type: draft.sport.rawValue, source: "manual", title: title,
            started_at: iso.string(from: draft.startedAt),
            ended_at: iso.string(from: draft.startedAt.addingTimeInterval(draft.elapsedTimeS)),
            duration_s: Int(draft.elapsedTimeS), total_calories: draft.calories,
            privacy: privacy.rawValue, is_indoor: draft.isIndoor,
            distance_m: draft.distanceM, moving_time_s: Int(draft.movingTimeS),
            elapsed_time_s: Int(draft.elapsedTimeS),
            elevation_gain_m: draft.elevationGainM, elevation_loss_m: draft.elevationLossM,
            avg_pace_s_per_km: draft.avgPaceSecPerKm, avg_speed_mps: draft.avgSpeedMps,
            max_speed_mps: draft.maxSpeedMps,
            polyline: polyline.isEmpty ? nil : polyline, bounds: bounds,
            start_lat: draft.points.first?.lat, start_lng: draft.points.first?.lng,
            end_lat: draft.points.last?.lat, end_lng: draft.points.last?.lng,
            notes: notes, gear_id: gearID?.uuidString
        )

        struct Inserted: Decodable { let id: UUID }
        let data = try await LIVA.supabase.from("workouts").insert(row).select("id").single().execute().data
        let workoutID = try AppJSON.decoder.decode(Inserted.self, from: data).id

        // Streams (best-effort; failure shouldn't block the save).
        if !draft.points.isEmpty {
            struct StreamRow: Encodable, Sendable {
                let workout_id: String
                let t: [Double]; let latlng: [[Double]]; let altitude: [Double]; let speed: [Double]
            }
            let t0 = draft.points.first!.timestamp
            let stream = StreamRow(
                workout_id: workoutID.uuidString,
                t: draft.points.map { $0.timestamp.timeIntervalSince(t0) },
                latlng: draft.points.map { [$0.lat, $0.lng] },
                altitude: draft.points.map(\.altitude),
                speed: draft.points.map(\.speed)
            )
            try? await LIVA.supabase.from("activity_streams").insert(stream).execute()
        }

        // Gear mileage.
        if let gearID, draft.distanceM > 0 {
            try? await LIVA.supabase.rpc("increment_gear_distance",
                params: ["g": AnyJSON.string(gearID.uuidString),
                         "meters": AnyJSON.double(draft.distanceM)]).execute()
        }

        let records = try await detectAndStorePRs(draft: draft, workoutID: workoutID, uid: uid)
        return SaveResult(workoutID: workoutID, newRecords: records)
    }

    private func detectAndStorePRs(draft: ActivitySummaryDraft, workoutID: UUID, uid: UUID) async throws -> [PersonalRecordItem] {
        var newRecords: [PersonalRecordItem] = []
        for candidate in PRDetection.candidates(draft: draft) {
            let existing = try? await bestRecord(type: candidate.type, uid: uid)
            guard PRDetection.isImprovement(type: candidate.type, candidate: candidate.value, existing: existing) else { continue }
            struct PRRow: Encodable, Sendable {
                let user_id: String; let workout_id: String; let record_type: String; let value: Double
            }
            try? await LIVA.supabase.from("personal_records").insert(
                PRRow(user_id: uid.uuidString, workout_id: workoutID.uuidString,
                      record_type: candidate.type, value: candidate.value)).execute()
            newRecords.append(PersonalRecordItem(recordType: candidate.type, value: candidate.value, achievedAt: Date()))
        }
        return newRecords
    }

    private func bestRecord(type: String, uid: UUID) async throws -> Double? {
        let ascending = type.hasPrefix("fastest_")
        let data = try await LIVA.supabase.from("personal_records").select("value")
            .eq("user_id", value: uid.uuidString).eq("record_type", value: type)
            .order("value", ascending: ascending).limit(1).execute().data
        struct R: Decodable { let value: Double }
        return try AppJSON.decoder.decode([R].self, from: data).first?.value
    }

    // MARK: Map snapshot + share to feed

    @MainActor
    func snapshot(points: [TrackPoint], size: CGSize = .init(width: 1080, height: 1080)) async -> UIImage? {
        guard points.count > 1 else { return nil }
        let coords = points.map(\.coordinate)
        var rect = MKMapRect.null
        for c in coords {
            let p = MKMapPoint(c)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect.insetBy(dx: -rect.size.width * 0.15, dy: -rect.size.height * 0.15)
        options.size = size
        options.pointOfInterestFilter = .excludingAll

        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            snapshot.image.draw(at: .zero)
            let path = UIBezierPath()
            for (i, c) in coords.enumerated() {
                let pt = snapshot.point(for: c)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            UIColor(Theme.Palette.accentDeep).setStroke()
            path.lineWidth = 8; path.lineJoinStyle = .round; path.lineCapStyle = .round
            path.stroke()
        }
    }

    /// Posts the activity to the Loops feed with a map thumbnail and stat caption.
    @MainActor
    func shareToFeed(draft: ActivitySummaryDraft, title: String) async throws {
        guard let image = await snapshot(points: draft.points),
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        let url = try await StorageService.upload(data, bucket: .posts, fileExtension: "jpg", contentType: "image/jpeg")
        guard let uid = LIVA.supabase.currentUserID else { return }
        let dist = String(format: "%.2f", HealthMath.metersToMiles(draft.distanceM))
        let pace = GPSMath.formatPace(secPerKm: draft.avgPaceSecPerKm, imperial: true)
        let caption = "\(title) · \(dist) mi · \(pace)/mi · \(GPSMath.formatDuration(draft.movingTimeS))"
        struct PostRow: Encodable, Sendable {
            let author_id: String; let media_url: String; let media_type: String
            let caption: String; let hashtags: [String]
        }
        try await LIVA.supabase.from("posts").insert(
            PostRow(author_id: uid.uuidString, media_url: url, media_type: "image",
                    caption: caption, hashtags: [draft.sport.title.lowercased(), "liva"])).execute()
    }
}
