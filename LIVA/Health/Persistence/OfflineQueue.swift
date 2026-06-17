import Foundation
import SwiftData
import Supabase

/// A durable, write-ahead log of mutations that couldn't reach Supabase (e.g.
/// offline). Replayed on launch and after each successful online write.
///
/// We chose **SwiftData** as the local store: native to iOS 17+, zero external
/// dependencies, and it composes cleanly with the Observation framework. The
/// queue is the offline-first backbone — manual logs always persist locally
/// first, so a dropped connection never loses a workout, weigh-in, or biometric.
@Model
final class PendingWrite {
    @Attribute(.unique) var id: UUID
    var table: String
    var payload: Data          // JSON-encoded row
    var onConflict: String?    // upsert conflict target, if any
    var createdAt: Date
    var attempts: Int

    init(table: String, payload: Data, onConflict: String? = nil) {
        self.id = UUID()
        self.table = table
        self.payload = payload
        self.onConflict = onConflict
        self.createdAt = Date()
        self.attempts = 0
    }
}

@MainActor
final class OfflineQueue {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// After this many failed (non-connectivity) attempts, a write is dropped.
    private let maxAttempts = 5

    init() {
        do {
            container = try ModelContainer(
                for: PendingWrite.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            // In-memory fallback keeps the app functional even if the store fails.
            container = try! ModelContainer(
                for: PendingWrite.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    /// Persist a failed write for later replay.
    func enqueue(table: String, payload: Data, onConflict: String?) {
        context.insert(PendingWrite(table: table, payload: payload, onConflict: onConflict))
        try? context.save()
    }

    var pendingCount: Int {
        (try? context.fetchCount(FetchDescriptor<PendingWrite>())) ?? 0
    }

    /// Replay all queued writes. Connectivity failures are kept; persistent
    /// server failures are dropped after `maxAttempts`.
    func flush() async {
        let items = (try? context.fetch(
            FetchDescriptor<PendingWrite>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        for item in items {
            do {
                let json = try AppJSON.decoder.decode(AnyJSON.self, from: item.payload)
                if let conflict = item.onConflict {
                    try await LIVA.supabase.from(item.table).upsert(json, onConflict: conflict).execute()
                } else {
                    try await LIVA.supabase.from(item.table).insert(json).execute()
                }
                context.delete(item)
            } catch {
                if NetworkReachability.isConnectivityError(error) {
                    break // still offline — stop, keep order, try again later
                } else {
                    item.attempts += 1
                    if item.attempts >= maxAttempts { context.delete(item) }
                }
            }
        }
        try? context.save()
    }
}

/// Classifies whether an error is a transient connectivity problem (so the
/// write should be retried) versus a real failure.
enum NetworkReachability {
    static func isConnectivityError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dataNotAllowed:
                return true
            default: return false
            }
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("offline") || text.contains("network connection")
    }
}
