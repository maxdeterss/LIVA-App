import Foundation
import Supabase

/// Wraps Supabase email/password authentication.
enum AuthService {

    /// Result of a sign-up attempt.
    enum SignUpOutcome {
        case signedIn               // session established immediately
        case needsEmailConfirmation // project has "Confirm email" enabled
    }

    /// Create an account. `username` is stored in user metadata and copied into
    /// the profile row by the `handle_new_user` trigger.
    @discardableResult
    static func signUp(email: String, password: String, username: String) async throws -> SignUpOutcome {
        let response = try await LIVA.supabase.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)]
        )
        return response.session == nil ? .needsEmailConfirmation : .signedIn
    }

    static func signIn(email: String, password: String) async throws {
        try await LIVA.supabase.auth.signIn(email: email, password: password)
    }

    static func signOut() async throws {
        try await LIVA.supabase.auth.signOut()
    }

    static func sendPasswordReset(email: String) async throws {
        try await LIVA.supabase.auth.resetPasswordForEmail(email)
    }
}
