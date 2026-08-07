//
//  SignupView.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import SwiftUI
import UIKit
import Supabase

struct SignupView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isPrivate = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var passwordError: String?
    @State private var usernameAvailability: UsernameAvailabilityOutcome?
    @State private var toastMessage: String?
    @State private var toastIsError: Bool = true
    @State private var showLogin = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

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
                        title: "Create your\nSpot account",
                        subtitle: "Let’s get you set up."
                    )
                    .padding(.horizontal, 28)

                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            CustomTextField(placeholder: "you@example.com", text: $email, systemImage: "envelope")
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .accessibilityIdentifier("auth.signup.emailField")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            CustomTextField(placeholder: "your.username", text: $username, systemImage: "person")
                                .textContentType(.username)
                                .accessibilityIdentifier("auth.signup.usernameField")
                                .task(id: username) {
                                    await checkUsernameAvailability()
                                }
                            if let usernameAvailability {
                                usernameAvailabilityMessage(usernameAvailability)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            CustomSecureField(placeholder: "Create a password", text: $password, systemImage: "lock")
                                .textContentType(.newPassword)
                                .accessibilityIdentifier("auth.signup.passwordField")
                            if let passwordError {
                                Text(passwordError)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            passwordRequirements
                        }
                        HStack {
                            Button(action: { isPrivate.toggle() }) {
                                Image(systemName: isPrivate ? "checkmark.square.fill" : "square")
                                    .foregroundColor(Constants.Colors.primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text("Private account")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                                .buttonStyle(PlainButtonStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 32)

                    Button(action: {
                        passwordError = nil

                        guard !email.isEmpty, !username.isEmpty, !password.isEmpty else {
                            showToast("Please fill in all fields.", isError: true)
                            return
                        }

                        // Username validation (client-fast)
                        let validator = UsernameValidator()
                        let usernameResult = validator.validate(username)
                        if let feedback = UsernameFeedback.message(for: usernameResult) {
                            if case .blocked = usernameResult {
                                SpotLogger.log(SignupViewLogs.usernameBlocked, details: [
                                    "raw": username,
                                    "norm": validator.normalized(username),
                                    "reason": "blocked"
                                ])
                            }
                            showToast(feedback, isError: true)
                            return
                        }

                        switch PasswordValidator.validate(password) {
                        case .ok:
                            break
                        case .failure(let message):
                            passwordError = message
                            return
                        }

                        isLoading = true
                        errorMessage = nil

                        // Profile picture is collected after the post-auth
                        // permission steps in `PostAuthSetupFlowView`, so signup
                        // here just captures the credentials and metadata.
                        validateAndSignUp()
                    }) {
                        Text(isLoading ? "Creating account..." : "Continue")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Constants.Colors.primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .accessibilityIdentifier("auth.signup.continueButton")

                    AuthDivider()
                        .padding(.horizontal, 32)

                    ThemedAppleSignInButton(
                        onSuccess: { dismiss() },
                        onError: { message in showToast(message, isError: true) },
                        height: 48
                    )
                    .padding(.horizontal, 32)

                    AuthLegalFooter()
                        .padding(.horizontal, 32)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)

                        Button(action: {
                            showLogin = true
                        }) {
                            Text("Log in")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer(minLength: 20)
                }
                }

                .navigationDestination(isPresented: $showLogin) {
                    LoginView()
                }
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    ToastView(message: toastMessage, isError: toastIsError)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("onboarding.signupScreen")
    }

    private func checkUsernameAvailability() async {
        let candidate = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .ok = UsernameValidator().validate(candidate) else {
            await MainActor.run { usernameAvailability = nil }
            return
        }
        try? await Task.sleep(nanoseconds: 450_000_000)
        guard !Task.isCancelled else { return }
        let outcome = await authVM.usernameAvailability(candidate)
        guard !Task.isCancelled else { return }
        await MainActor.run { usernameAvailability = outcome }
    }

    @ViewBuilder
    private func usernameAvailabilityMessage(_ outcome: UsernameAvailabilityOutcome) -> some View {
        switch outcome {
        case .available:
            Label("Username is available", systemImage: "checkmark.circle.fill")
                .foregroundColor(Constants.Colors.mapFilterMatch)
        case .taken:
            Label("That username is taken", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
        case .unavailable:
            Label("We couldn’t check that username. Try again.", systemImage: "arrow.clockwise.circle")
                .foregroundColor(Constants.Colors.welcomeMutedText)
        }
    }

    private var passwordRequirements: some View {
        let checks = PasswordRequirementChecks.evaluate(password)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(checks, id: \.label) { requirement in
                Label(requirement.label, systemImage: requirement.isMet ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundColor(requirement.isMet ? Constants.Colors.mapFilterMatch : Constants.Colors.welcomeMutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func validateAndSignUp() {
        Task {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let outcome = await authVM.usernameAvailability(trimmedUsername)
            await MainActor.run { usernameAvailability = outcome }
            switch outcome {
            case .available:
                await MainActor.run { self.signUpWithSupabase() }
            case .taken, .unavailable:
                await MainActor.run {
                    self.isLoading = false
                    if let feedback = UsernameAvailabilityFeedback.message(for: outcome) {
                        self.showToast(feedback, isError: true)
                    }
                }
            }
        }
    }

    private func signUpWithSupabase() {
        isLoading = true
        errorMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let response = try await supabase.auth.signUp(
                    email: cleanEmail,
                    password: password,
                    data: [
                        "username": .string(trimmedUsername),
                        "is_private": .bool(isPrivate)
                    ]
                )

                // Supabase does not throw when an email is already registered
                // (email-enumeration protection). Instead it returns HTTP 200
                // with no session and an empty `identities` array, and it does
                // NOT send a confirmation email. Detect that here so the user
                // isn't stranded on the verification screen waiting for a code
                // that will never arrive.
                let isExistingAccount = AuthErrorClassifier.isExistingAccountSignup(
                    hasSession: response.session != nil,
                    identityCount: response.user.identities?.count ?? 0
                )
                if isExistingAccount {
                    SpotLogger.log(SignupViewLogs.emailAlreadyRegistered)
                    await MainActor.run {
                        AnalyticsService.shared.trackAuthEvent(
                            Constants.Analytics.authEmailInUse,
                            parameters: ["action": "detected", "surface": "signup"]
                        )
                        self.isLoading = false
                        self.showToast(
                            "We couldn’t create this account. Try logging in or resetting your password.",
                            isError: true
                        )
                    }
                    return
                }

                await MainActor.run {
                    AnalyticsService.shared.setUserId(response.user.id.uuidString)
                    AnalyticsService.shared.logEvent("user_signup", parameters: [
                        "email_verified": response.user.emailConfirmedAt != nil
                    ])
                }

                await MainActor.run {
                    if response.session == nil {
                        authVM.beginEmailVerificationPending(
                            email: cleanEmail,
                            avatar: nil,
                            userId: response.user.id
                        )
                    } else {
                        authVM.clearEmailVerificationPending()
                    }
                    self.isLoading = false
                    self.errorMessage = nil
                    if response.session == nil {
                        self.showToast("Check your email for the verification code.", isError: false)
                    }
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showToast(error.localizedDescription, isError: true)
                }
            }
        }
    }

    private func showToast(_ message: String, isError: Bool) {
        withAnimation {
            toastMessage = message
            toastIsError = isError
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }
}

// MARK: - Custom Reusable Fields

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(Constants.Colors.welcomeMutedText)
            }
            TextField(placeholder, text: $text)
                .font(.callout)
                .foregroundColor(Constants.Colors.primary)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Constants.Colors.welcomeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Constants.Colors.primary.opacity(0.22), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(Constants.Colors.welcomeMutedText)
            }
            SecureField(placeholder, text: $text)
                .font(.callout)
                .foregroundColor(Constants.Colors.primary)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Constants.Colors.welcomeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Constants.Colors.primary.opacity(0.22), lineWidth: 1)
        )
    }
}

#Preview {
    SignupView()
        .environmentObject(AuthViewModel())
}
