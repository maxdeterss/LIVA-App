import Foundation
import Supabase

/// Uploads media to Supabase Storage. Files live under a per-user folder
/// (`<uid>/...`) so the storage RLS policy authorises the write.
enum StorageService {

    enum Bucket: String { case avatars, posts }

    /// Uploads `data` and returns its public URL.
    static func upload(
        _ data: Data,
        bucket: Bucket,
        fileExtension: String,
        contentType: String
    ) async throws -> String {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        // Folder must match auth.uid()::text, which Postgres renders lowercase —
        // Swift's uuidString is uppercase, so normalise both segments.
        let path = "\(uid.uuidString.lowercased())/\(UUID().uuidString.lowercased()).\(fileExtension)"
        _ = try await LIVA.supabase.storage
            .from(bucket.rawValue)
            .upload(path, data: data, options: FileOptions(contentType: contentType, upsert: true))
        let url = try LIVA.supabase.storage.from(bucket.rawValue).getPublicURL(path: path)
        return url.absoluteString
    }
}
