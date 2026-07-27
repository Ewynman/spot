//
//  LoginView.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import SwiftUI
import Supabase

struct LoginView: View {
    @State private var loginIdentifier: String
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resetMessage: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    init(initialIdentifier: String = "") {
        _loginIdentifier = State(initialValue: initialIdentifier)
    }

    private func handleLoginError(_ error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("network") || text.contains("internet") {
            return "Network error. Please check your connection."
        }
        if text.contains("email not confirmed") || text.contains("email_not_confirmed") {
            return "Verify your email to finish creating your account."
        }
        if text.contains("enter the email") {
            return "Enter the email address for your account."
        }
        if text.contains("username") || text.contains("no account found") {
            return "No account found for that username."
        }
        return "Incorrect email or password."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                ScrollView {
                VStack(spacing: 22) {
                    // Custom Back Button
                    HStack {
                        CustomBackButton {
                            dismiss()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    AuthWordmark()
                        .padding(.top, 4)

                    AuthScreenHeader(
                        title: "Log in",
                        subtitle: "Welcome back! Glad to see you again."
                    )
                    .padding(.horizontal, 28)

                    // Fields with labels (match Settings style)
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            CustomTextField(placeholder: "you@example.com", text: $loginIdentifier, systemImage: "envelope")
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .accessibilityIdentifier("auth.login.emailField")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            CustomSecureField(placeholder: "Enter your password", text: $password, systemImage: "lock")
                                .textContentType(.password)
                                .accessibilityIdentifier("auth.login.passwordField")
                        }
                    }
                    .padding(.horizontal, 32)

                    // Forgot Password
                    HStack {
                        Spacer()
                        Button(action: {
                            let trimmed = loginIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, trimmed.contains("@") else {
                                errorMessage = "Enter your email to reset your password"
                                return
                            }
                            errorMessage = nil
                            resetMessage = nil
                            Task {
                                do {
                                    try await AuthService.shared.resetPassword(email: trimmed)
                                    SpotLogger.log(LoginViewLogs.passwordResetRequested)
                                    await MainActor.run { resetMessage = "Password reset link sent. Check your email." }
                                } catch {
                                    SpotLogger.log(LoginViewLogs.passwordResetError, details: ["error": error.localizedDescription])
                                    await MainActor.run { errorMessage = "Could not send reset email. Please try again." }
                                }
                            }
                        }) {
                            Text("Forgot password?")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 32)

                    // Login Button
                    Button(action: {
                        guard !loginIdentifier.isEmpty, !password.isEmpty else {
                            errorMessage = "Please fill in all fields"
                            return
                        }

                        isLoading = true
                        errorMessage = nil

                        Task {
                            do {
                                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                    AuthService.shared.signIn(
                                        identifier: loginIdentifier,
                                        password: password
                                    ) { result in
                                        switch result {
                                        case .success:
                                            continuation.resume(returning: ())
                                        case .failure(let error):
                                            continuation.resume(throwing: error)
                                        }
                                    }
                                }
                                await MainActor.run {
                                    isLoading = false
                                    SpotLogger.log(LoginViewLogs.loginSuccess)
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isLoading = false
                                    errorMessage = handleLoginError(error)
                                    let raw = error.localizedDescription.lowercased()
                                    if raw.contains("email not confirmed") || raw.contains("email_not_confirmed") {
                                        authVM.beginEmailVerificationPending(email: loginIdentifier, avatar: nil)
                                        dismiss()
                                    }
                                    SpotLogger.log(LoginViewLogs.loginFailed, details: ["error": error.localizedDescription])
                                }
                            }
                        }
                    }) {
                        Text(isLoading ? "Logging in..." : "Log in")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Constants.Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier("auth.login.submitButton")

                    AuthDivider()
                        .padding(.horizontal, 32)

                    ThemedAppleSignInButton(
                        onSuccess: {
                            SpotLogger.log(LoginViewLogs.loginSuccess)
                            dismiss()
                        },
                        onError: { message in
                            errorMessage = message
                            SpotLogger.log(LoginViewLogs.loginFailed, details: ["error": message])
                        },
                        height: 48
                    )
                    .padding(.horizontal, 32)

                    // Error Text
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(FontManager.primaryText())
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .padding(.horizontal, 32)
                    }
                    // Reset success
                    if let msg = resetMessage {
                        Text(msg)
                            .foregroundColor(.green)
                            .font(FontManager.primaryText())
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .padding(.horizontal, 32)
                    }

                    // Link to Sign Up
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)

                        NavigationLink(destination: SignupView()) {
                            Text("Create an account")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                                .buttonStyle(PlainButtonStyle())
                        }
                    }

                    Spacer(minLength: 24)
                }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("auth.login.screen")
        .onAppear {
            if loginIdentifier.isEmpty {
                loginIdentifier = AuthAccountHintStore.shared.load()?.email ?? ""
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
