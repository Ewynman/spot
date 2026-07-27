//
//  ThemedAppleSignInButton.swift
//  Spot
//
//  Created by Edward Wynman on 4/20/2026.
//

import SwiftUI
import AuthenticationServices

enum ThemedAppleSignInButtonMode {
    case signIn
    case accountDeletionReauth
}

struct ThemedAppleSignInButton: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isInFlight = false
    @State private var currentNonce: String?

    var mode: ThemedAppleSignInButtonMode = .signIn
    var onRequest: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil
    var onError: ((String) -> Void)? = nil
    /// When `mode` is `.accountDeletionReauth`, called with the Apple identity token and raw nonce.
    var onAppleIDToken: ((_ idToken: String, _ nonce: String) -> Void)? = nil
    var height: CGFloat = 56

    private var buttonLabel: SignInWithAppleButton.Label {
        switch mode {
        case .signIn: return .signIn
        case .accountDeletionReauth: return .continue
        }
    }

    var body: some View {
        SignInWithAppleButton(
            buttonLabel,
            onRequest: { request in
                guard !isInFlight else { return }
                isInFlight = true
                let nonce = AppleSignInNonce.make()
                currentNonce = nonce
                request.nonce = AppleSignInNonce.sha256(nonce)
                onRequest?()
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                handleAppleResult(result)
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Constants.Colors.primary, lineWidth: 1)
        )
        .opacity(isInFlight ? 0.72 : 1)
        .allowsHitTesting(!isInFlight)
        .accessibilityIdentifier(mode == .accountDeletionReauth
                                 ? "settings.deleteAccountAppleButton"
                                 : "auth.signInWithAppleButton")
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            isInFlight = false
            currentNonce = nil
            onError?(error.localizedDescription)
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                isInFlight = false
                currentNonce = nil
                onError?("Could not read Apple credential.")
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  !idToken.isEmpty,
                  let nonce = currentNonce
            else {
                isInFlight = false
                currentNonce = nil
                onError?("Apple did not return a valid identity token.")
                return
            }

            Task {
                switch mode {
                case .accountDeletionReauth:
                    await MainActor.run {
                        isInFlight = false
                        currentNonce = nil
                        onAppleIDToken?(idToken, nonce)
                    }
                case .signIn:
                    do {
                        try await authVM.signInWithApple(
                            idToken: idToken,
                            nonce: nonce,
                            fullName: credential.fullName
                        )
                        await MainActor.run {
                            isInFlight = false
                            currentNonce = nil
                            onSuccess?()
                        }
                    } catch {
                        await MainActor.run {
                            isInFlight = false
                            currentNonce = nil
                            onError?(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
