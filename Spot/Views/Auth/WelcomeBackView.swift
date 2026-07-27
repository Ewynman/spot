import SwiftUI

struct WelcomeBackView: View {
    let account: AuthAccountHint
    let onUseAnotherAccount: () -> Void

    @State private var showLogin = false
    @State private var appleError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                AuthWordmark()
                    .padding(.top, 34)

                Spacer(minLength: 20)

                AuthScreenHeader(
                    title: "Welcome back",
                    subtitle: "Choose your account to keep exploring great places."
                )

                accountCard

                if account.provider == .apple {
                    ThemedAppleSignInButton(
                        onError: { appleError = $0 },
                        height: 52
                    )
                } else {
                    AuthPrimaryButton(title: "Continue as \(account.displayLabel)") {
                        showLogin = true
                    }
                    .accessibilityIdentifier("auth.welcomeBack.continueButton")
                }

                AuthSecondaryButton(title: "Use another account", action: onUseAnotherAccount)
                    .accessibilityIdentifier("auth.welcomeBack.useAnotherAccount")

                if let appleError {
                    Text(appleError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Label(
                    account.provider == .apple
                        ? "Secured with Sign in with Apple"
                        : "Account suggestion synced by iCloud Keychain",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundColor(Constants.Colors.welcomeMutedText)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .background(Constants.Colors.background.ignoresSafeArea())
            .navigationDestination(isPresented: $showLogin) {
                LoginView(initialIdentifier: account.email ?? "")
            }
        }
        .accessibilityIdentifier("auth.welcomeBack.screen")
    }

    private var accountCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Constants.Colors.accent)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String(account.displayLabel.filter(\.isLetter).prefix(1)).uppercased())
                        .font(.title2.weight(.bold))
                        .foregroundColor(Constants.Colors.primary)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(account.displayLabel)
                    .font(.title3.weight(.bold))
                    .foregroundColor(Constants.Colors.primary)
                if let maskedEmail = account.maskedEmail {
                    Text(maskedEmail)
                        .font(.footnote)
                        .foregroundColor(Constants.Colors.welcomeMutedText)
                }
            }

            Spacer()
        }
        .padding(18)
        .background(Constants.Colors.accent.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Constants.Colors.primary.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeBackView(
        account: AuthAccountHint(
            email: "maya@example.com",
            displayLabel: "@maya",
            provider: .email,
            lastSignedInAt: .now
        ),
        onUseAnotherAccount: {}
    )
    .environmentObject(AuthViewModel())
}
