import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode { case signIn, signUp }

    @Published var mode: Mode = .signIn
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isWorking = false
    @Published var error: String?
    @Published var notice: String?

    var canSubmit: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passOK = password.count >= 6
        let userOK = mode == .signIn || username.trimmingCharacters(in: .whitespaces).count >= 3
        return emailOK && passOK && userOK
    }

    func submit() async {
        error = nil; notice = nil
        isWorking = true
        defer { isWorking = false }

        do {
            switch mode {
            case .signIn:
                try await AuthService.signIn(email: cleanedEmail, password: password)
                // Auth state observer routes the app onward.
            case .signUp:
                let name = username.trimmingCharacters(in: .whitespaces)
                guard try await ProfileService.usernameAvailable(name) else {
                    error = "That username is already taken."
                    return
                }
                let outcome = try await AuthService.signUp(
                    email: cleanedEmail, password: password, username: name
                )
                if outcome == .needsEmailConfirmation {
                    notice = "Check your inbox to confirm your email, then sign in."
                    mode = .signIn
                }
            }
        } catch {
            self.error = friendly(error)
        }
    }

    func resetPassword() async {
        guard email.contains("@") else {
            error = "Enter your email first."
            return
        }
        do {
            try await AuthService.sendPasswordReset(email: cleanedEmail)
            notice = "Password reset link sent to your email."
        } catch {
            self.error = friendly(error)
        }
    }

    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func friendly(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("invalid login") {
            return "Incorrect email or password."
        }
        return text
    }
}
