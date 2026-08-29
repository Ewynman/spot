//
//  TermsAgreementCheckboxView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import UIKit

struct TermsAgreementCheckboxView: View {
    @Binding var isAgreed: Bool
    let termsURL: URL
    let privacyURL: URL
    let onLinkTapped: ((String) -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                isAgreed.toggle()
            } label: {
                Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAgreed
                                ? "Terms agreement checked"
                                : "Terms agreement not checked")
            .accessibilityIdentifier("auth.termsCheckbox")

            agreementText
                .accessibilityIdentifier("auth.termsAgreementText")
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agreementText: some View {
        Text(attributedAgreementText)
            .font(.footnote)
            .foregroundColor(Constants.Colors.welcomeMutedText)
            .tint(Constants.Colors.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    if url == termsURL {
                        onLinkTapped?("terms")
                    } else if url == privacyURL {
                        onLinkTapped?("privacy")
                    }
                    UIApplication.shared.open(url)
                    return .handled
                }
            )
    }

    private var attributedAgreementText: AttributedString {
        var text = AttributedString("I agree to Spot's ")

        var terms = AttributedString("Terms of Use (EULA)")
        terms.link = termsURL
        text.append(terms)

        text.append(AttributedString(" and "))

        var privacy = AttributedString("Privacy Policy")
        privacy.link = privacyURL
        text.append(privacy)

        text.append(AttributedString("."))
        return text
    }
}

#Preview("Unchecked") {
    TermsAgreementCheckboxPreviewHost(initialAgreed: false)
}

#Preview("Checked") {
    TermsAgreementCheckboxPreviewHost(initialAgreed: true)
}

private struct TermsAgreementCheckboxPreviewHost: View {
    @State private var isAgreed: Bool

    init(initialAgreed: Bool) {
        _isAgreed = State(initialValue: initialAgreed)
    }

    var body: some View {
        TermsAgreementCheckboxView(
            isAgreed: $isAgreed,
            termsURL: PreAuthTermsAgreementStore.fallbackTermsURL,
            privacyURL: PreAuthTermsAgreementStore.fallbackPrivacyURL,
            onLinkTapped: nil
        )
        .padding()
        .background(Constants.Colors.background)
    }
}
