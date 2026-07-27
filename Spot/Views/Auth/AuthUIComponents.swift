import SwiftUI

struct AuthWordmark: View {
    var body: some View {
        Text("SPOT")
            .font(FontManager.logoTitle())
            .tracking(5)
            .foregroundColor(Constants.Colors.primary)
            .accessibilityLabel("Spot")
    }
}

struct AuthScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(Constants.Colors.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.callout)
                .foregroundColor(Constants.Colors.welcomeMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AuthPrimaryButton: View {
    let title: String
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(Constants.Colors.buttonText)
                }
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .foregroundColor(Constants.Colors.buttonText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Constants.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct AuthSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Constants.Colors.welcomeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Constants.Colors.primary.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Constants.Colors.welcomeLine.opacity(0.55))
                .frame(height: 1)
            Text("or")
                .font(.footnote)
                .foregroundColor(Constants.Colors.welcomeMutedText)
            Rectangle()
                .fill(Constants.Colors.welcomeLine.opacity(0.55))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

struct AuthLegalFooter: View {
    var body: some View {
        VStack(spacing: 5) {
            Text("By continuing, you agree to Spot’s Terms of Use and acknowledge our Privacy Policy.")
                .font(.caption2)
                .foregroundColor(Constants.Colors.welcomeMutedText)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("Open Terms", destination: Constants.Legal.termsURL)
                    .accessibilityIdentifier("auth.footer.openTerms")
                Link("Open Privacy", destination: Constants.Legal.privacyURL)
                    .accessibilityIdentifier("auth.footer.openPrivacy")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(Constants.Colors.primary)
            .underline()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Auth controls") {
    VStack(spacing: 16) {
        AuthWordmark()
        AuthScreenHeader(title: "Welcome back", subtitle: "Glad to see you again.")
        AuthPrimaryButton(title: "Continue", action: {})
        AuthSecondaryButton(title: "Use another account", action: {})
        AuthDivider()
        AuthLegalFooter()
    }
    .padding(28)
    .background(Constants.Colors.background)
}
