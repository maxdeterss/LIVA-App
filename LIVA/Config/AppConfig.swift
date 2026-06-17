import Foundation

/// Reads Supabase connection details from `Supabase-Info.plist`.
///
/// Keeping these in a plist (rather than hardcoded) makes it trivial to point
/// the app at a different environment without touching code.
enum AppConfig {
    static let supabaseURL: URL = {
        guard let url = URL(string: value(for: "SUPABASE_URL")) else {
            fatalError("SUPABASE_URL is missing or malformed in Supabase-Info.plist")
        }
        return url
    }()

    static let supabaseAnonKey: String = value(for: "SUPABASE_ANON_KEY")

    private static func value(for key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: "Supabase-Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let value = dict[key] as? String,
            !value.isEmpty
        else {
            fatalError("Missing \(key) in Supabase-Info.plist")
        }
        return value
    }
}
