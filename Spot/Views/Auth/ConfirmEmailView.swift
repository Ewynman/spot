//
//  ConfirmEmailView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct ConfirmEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var showToast: String?
    #if DEBUG || INTERNAL_TESTING
    @State private var showInternalCodeEntry = false
    @State private var internalTestCode = ""
    @State private var isVerifyingInternal = false
    #endif

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    authVM.clearEmailVerificationPending()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            AuthWordmark()
                .padding(.top, 4)

            AuthScreenHeader(
                title: "Check your email",
                subtitle: "We sent a 6-digit code to \(authVM.maskedEmail)."
            )
            .padding(.horizontal, 28)

            Label(
                "You’ll only need this code when creating your account.",
                systemImage: "envelope.badge"
            )
            .font(.footnote)
            .foregroundColor(Constants.Colors.welcomeMutedText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Constants.Colors.accent.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 28)

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: Binding(
                        get: { otpDigits[index] },
                        set: { newValue in
                            otpDigits = OTPDigitField.applyPaste(newValue, into: otpDigits, at: index)
                            if !newValue.isEmpty, index < 5 {
                                focusedIndex = index + 1
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .textContentType(index == 0 ? .oneTimeCode : nil)
                    .multilineTextAlignment(.center)
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .tint(Constants.Colors.primary)
                    .frame(width: 44, height: 52)
                    .background(Constants.Colors.welcomeSurface)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.primary.opacity(0.25), lineWidth: 1))
                    .focused($focusedIndex, equals: index)
                    .onChange(of: otpDigits[index]) { oldValue, newValue in
                        if newValue.isEmpty && !oldValue.isEmpty && index > 0 {
                            focusedIndex = index - 1
                        }
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityIdentifier("auth.confirmEmail.otp")

            if let errorMessage {
                Text(errorMessage)
                    .font(FontManager.primaryText())
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                Task { await verifyTapped() }
            } label: {
                Text(isVerifying ? "Verifying..." : "Verify")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isVerifying || otpCode.count != 6)
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .accessibilityIdentifier("auth.confirmEmail.verifyButton")

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Button {
                    Task { await resend() }
                } label: {
                    if authVM.canResendVerification() {
                        Text(isResending ? "Sending..." : "Resend code")
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                    } else {
                        Text("Resend in \(authVM.secondsUntilResend())s")
                            .font(FontManager.primaryText())
                            .foregroundColor(.gray)
                    }
                }
                .disabled(!authVM.canResendVerification() || isResending)
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("auth.confirmEmail.resendButton")
            }

            #if DEBUG || INTERNAL_TESTING
            if authVM.isInternalTestEmailVerificationAvailable {
                internalTestCodeSection
            }
            #endif

            AuthDivider()
                .padding(.horizontal, 32)

            Button {
                authVM.clearEmailVerificationPending()
                dismiss()
            } label: {
                Text("Use a different email")
                    .font(.callout.weight(.medium))
                    .foregroundColor(Constants.Colors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.confirmEmail.useDifferentEmail")

            Spacer()
        }
        .background(Constants.Colors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("auth.confirmEmail.screen")
        .onAppear { focusedIndex = 0 }
        .overlay(alignment: .top) {
            if let msg = showToast {
                ToastView(message: msg, isError: false)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showToast = nil } } }
            }
        }
    }

    private var otpCode: String {
        otpDigits.joined()
    }

    #if DEBUG || INTERNAL_TESTING
    @ViewBuilder
    private var internalTestCodeSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showInternalCodeEntry.toggle()
                }
            } label: {
                Text(showInternalCodeEntry ? "Hide internal test code" : "Use internal test code")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.confirmEmail.internalTestToggle")

            if showInternalCodeEntry {
                TextField("UT1234", text: $internalTestCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Constants.Colors.welcomeSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Constants.Colors.primary.opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier("auth.confirmEmail.internalTestCode")

                Button {
                    Task { await verifyInternalTapped() }
                } label: {
                    Text(isVerifyingInternal ? "Verifying..." : "Verify internal code")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isVerifyingInternal || isVerifying || !StagingTestEmailVerification.isValidCodeFormat(internalTestCode))
                .padding(.horizontal, 32)
                .accessibilityIdentifier("auth.confirmEmail.internalTestVerifyButton")
            }
        }
        .padding(.top, 4)
    }

    private func verifyInternalTapped() async {
        errorMessage = nil
        isVerifyingInternal = true
        defer { isVerifyingInternal = false }
        do {
            try await authVM.verifyInternalTestEmailCode(internalTestCode)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    private func verifyTapped() async {
        errorMessage = nil
        isVerifying = true
        defer { isVerifying = false }
        do {
            try await authVM.verifySignupEmailOTP(code: otpCode)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resend() async {
        guard authVM.canResendVerification() else { return }
        isResending = true
        defer { isResending = false }
        errorMessage = nil
        do {
            try await authVM.sendVerificationEmail()
            showToast = "Code sent"
            SpotLogger.log(ConfirmEmailViewLogs.verificationEmailResent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.beginEmailVerificationPending(email: "hello@example.com", avatar: nil)
    return ConfirmEmailView().environmentObject(auth)
}
