import Foundation
import Supabase

/// Shared Supabase client for the whole app.
///
/// `supabase` is the single entry point used by every service. The auth
/// session is automatically persisted to the keychain by the SDK.
enum LIVA {
    static let supabase = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}

/// Convenience accessors used throughout the services layer.
extension SupabaseClient {
    /// The currently authenticated user id, or nil when signed out.
    var currentUserID: UUID? {
        auth.currentUser?.id
    }
}
