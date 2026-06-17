import Foundation

/// User-facing errors raised by the services layer.
enum AppError: LocalizedError {
    case notAuthenticated
    case usernameTaken
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You need to be signed in to do that."
        case .usernameTaken: return "That username is already taken."
        case .message(let text): return text
        }
    }
}
