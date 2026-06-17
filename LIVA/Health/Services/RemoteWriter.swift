import Foundation
import Supabase

/// Offline-aware write helper. Attempts the remote write; on a connectivity
/// error it persists the row to the `OfflineQueue` for later replay. Other
/// (server) errors propagate so callers can surface them.
struct RemoteWriter {
    let queue: OfflineQueue

    func insert<T: Encodable & Sendable>(_ table: String, _ payload: T) async throws {
        do {
            try await LIVA.supabase.from(table).insert(payload).execute()
        } catch {
            guard NetworkReachability.isConnectivityError(error) else { throw error }
            try await persist(table, payload, onConflict: nil)
        }
    }

    func upsert<T: Encodable & Sendable>(_ table: String, _ payload: T, onConflict: String) async throws {
        do {
            try await LIVA.supabase.from(table).upsert(payload, onConflict: onConflict).execute()
        } catch {
            guard NetworkReachability.isConnectivityError(error) else { throw error }
            try await persist(table, payload, onConflict: onConflict)
        }
    }

    private func persist<T: Encodable>(_ table: String, _ payload: T, onConflict: String?) async throws {
        let data = try AppJSON.encoder.encode(payload)
        await MainActor.run { queue.enqueue(table: table, payload: data, onConflict: onConflict) }
    }
}
