import SwiftUI

/// Email/password sign-in & sign-up, styled after the LIVA waitlist page.
struct AuthView: View {
    @StateObject private var model = AuthViewModel()
    @FocusState private var focus: Field?

    enum Field { case username, email, password }

    var body: some View {
        ZStack {
            LivaBackground()
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    header
                    form
                    footer
                }
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            Text("LIVA").font(.wordmark(72)).tracking(-3)
                .foregroundStyle(Theme.Palette.ink)
            Text("Fitness, nutrition & mindset — in one place.")
                .font(.brandSerif(17))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 12)
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 14) {
            Picker("", selection: $model.mode) {
                Text("Sign In").tag(AuthViewModel.Mode.signIn)
                Text("Create Account").tag(AuthViewModel.Mode.signUp)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            if model.mode == .signUp {
                field(icon: "at", placeholder: "username", text: $model.username,
                      field: .username, autocap: .never)
            }
            field(icon: "envelope", placeholder: "your@email.com", text: $model.email,
                  field: .email, keyboard: .emailAddress, autocap: .never)
            secureField(icon: "lock", placeholder: "password", text: $model.password)

            if let error = model.error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.like)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let notice = model.notice {
                Text(notice)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.accentDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                focus = nil
                Task { await model.submit() }
            } label: {
                HStack {
                    if model.isWorking { ProgressView().tint(Theme.Palette.tabBarText) }
                    Text(model.mode == .signIn ? "Sign In" : "Create Account")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isWorking || !model.canSubmit)
            .opacity(model.canSubmit ? 1 : 0.6)
            .padding(.top, 4)

            if model.mode == .signIn {
                Button("Forgot password?") { Task { await model.resetPassword() } }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    private var footer: some View {
        Text("By continuing you agree to LIVA's Terms & Privacy Policy.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.Palette.inkTertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    // MARK: Field builders

    private func field(
        icon: String, placeholder: String, text: Binding<String>,
        field: Field, keyboard: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .sentences
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.Palette.inkSecondary).frame(width: 20)
            TextField(placeholder, text: text)
                .focused($focus, equals: field)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
        }
        .inputFieldStyle()
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.Palette.inkSecondary).frame(width: 20)
            SecureField(placeholder, text: text)
                .focused($focus, equals: .password)
                .textInputAutocapitalization(.never)
        }
        .inputFieldStyle()
    }
}

// MARK: - Input field style

extension View {
    /// Pale rounded text field used across auth and logging forms.
    func inputFieldStyle() -> some View {
        self
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.Palette.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )
    }
}
