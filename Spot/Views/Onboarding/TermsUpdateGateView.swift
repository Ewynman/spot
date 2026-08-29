//
//  TermsUpdateGateView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import UIKit

struct TermsUpdateGateView: View {
    let activeVersion: ActiveTermsVersion
    let onAccepted: () -> Void

    @State private var isAgreed: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private let service: TermsAcceptanceServicing

    init(activeVersion: ActiveTermsVersion,
         service: TermsAcceptanceServicing = TermsAcceptanceService.shared,
         onAccepted: @escaping () -> Void) {
        self.activeVersion = activeVersion
        self.service = service
        self.onAccepted = onAccepted
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Updated Terms")
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)

                    Text("We've updated Spot's Terms of Use and Privacy Policy. Please review and accept them to continue.")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.welcomeMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                bulletList
                    .padding(.vertical, 8)

                TermsAgreementCheckboxView(
                    isAgreed: $isAgreed,
                    termsURL: activeVersion.termsURL,
                    privacyURL: activeVersion.privacyURL,
                    onLinkTapped: nil
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await accept() }
                } label: {
                    Text(isSubmitting ? "Saving…" : "Accept and Continue")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isAgreed && !isSubmitting
                                    ? Constants.Colors.primary
                                    : Constants.Colors.primary.opacity(0.4))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isAgreed || isSubmitting)
                .accessibilityIdentifier("auth.acceptUpdatedTermsButton")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 80)
        }
        .accessibilityIdentifier("auth.termsUpdateGate")
        .onAppear {
            SpotLogger.log(TermsAcceptanceLogs.postAuthGatePresented, details: [
                "version": activeVersion.version
            ])
        }
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: 10) {
            bullet("Spot has zero tolerance for objectionable content or abusive users.")
            bullet("You can report content or block other users from inside the app.")
            bullet("We act on reported content within 24 hours when appropriate.")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Constants.Colors.primary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Constants.Colors.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @MainActor
    private func accept() async {
        guard isAgreed else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await service.recordAcceptance()
            SpotLogger.log(TermsAcceptanceLogs.postAuthGateAccepted, details: [
                "version": activeVersion.version
            ])
            onAccepted()
        } catch {
            isSubmitting = false
            errorMessage = "We couldn't save your acceptance. Check your connection and try again."
        }
    }
}

#Preview {
    TermsUpdateGateView(
        activeVersion: ActiveTermsVersion(
            id: UUID(),
            version: "2026-05-ugc-moderation",
            title: "Spot Terms of Use - UGC Moderation Update",
            termsURL: PreAuthTermsAgreementStore.fallbackTermsURL,
            privacyURL: PreAuthTermsAgreementStore.fallbackPrivacyURL
        ),
        onAccepted: {}
    )
}
