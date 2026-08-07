//
//  PreAuthTermsAgreementStoreTests.swift
//  SpotTests
//
//  Verifies the pre-auth Terms / Privacy gate state machine the Welcome screen
//  relies on. The store is intentionally transient (cold-launch resets the
//  agreement) so App Review reviewers consistently see the unchecked state.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct PreAuthTermsAgreementStoreTests {

    private final class StubTermsAcceptanceService: TermsAcceptanceServicing {
        var loadResult: Result<ActiveTermsVersion, Error>
        var loadCallCount = 0

        init(loadResult: Result<ActiveTermsVersion, Error>) {
            self.loadResult = loadResult
        }

        func loadActiveVersion() async throws -> ActiveTermsVersion {
            loadCallCount += 1
            return try loadResult.get()
        }
        func recordAcceptance() async throws {}
        func hasAcceptedActiveTerms() async throws -> Bool { false }
    }

    private static let sampleVersion = ActiveTermsVersion(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000aaaa")!,
        version: "2026-05-ugc-moderation",
        title: "Spot Terms of Use",
        termsURL: URL(string: "https://spotapp.online/terms#2026-05")!,
        privacyURL: URL(string: "https://spotapp.online/privacy#2026-05")!
    )

    @Test func defaultStateRequiresExplicitAgreement() {
        let store = PreAuthTermsAgreementStore(
            service: StubTermsAcceptanceService(loadResult: .success(Self.sampleVersion))
        )

        #expect(store.hasAgreed == false)
        #expect(store.activeVersion == nil)
        #expect(store.termsURL == PreAuthTermsAgreementStore.fallbackTermsURL)
        #expect(store.privacyURL == PreAuthTermsAgreementStore.fallbackPrivacyURL)
    }

    @Test func setAgreedTogglesPublishedFlag() {
        let store = PreAuthTermsAgreementStore(
            service: StubTermsAcceptanceService(loadResult: .success(Self.sampleVersion))
        )

        store.setAgreed(true)
        #expect(store.hasAgreed == true)

        store.setAgreed(false)
        #expect(store.hasAgreed == false)
    }

    @Test func resetClearsAgreementAndCachedVersion() async {
        let stub = StubTermsAcceptanceService(loadResult: .success(Self.sampleVersion))
        let store = PreAuthTermsAgreementStore(service: stub)

        await store.loadActiveVersion()
        store.setAgreed(true)
        #expect(store.activeVersion != nil)
        #expect(store.hasAgreed == true)

        store.reset()
        #expect(store.hasAgreed == false)
        #expect(store.activeVersion == nil)
    }

    @Test func loadActiveVersionPopulatesURLsOnSuccess() async {
        let stub = StubTermsAcceptanceService(loadResult: .success(Self.sampleVersion))
        let store = PreAuthTermsAgreementStore(service: stub)

        await store.loadActiveVersion()

        #expect(store.activeVersion == Self.sampleVersion)
        #expect(store.termsURL.absoluteString == "https://spotapp.online/terms#2026-05")
        #expect(store.privacyURL.absoluteString == "https://spotapp.online/privacy#2026-05")
        #expect(stub.loadCallCount == 1)
    }

    @Test func loadActiveVersionFailureFallsBackToHardcodedURLs() async {
        let stub = StubTermsAcceptanceService(
            loadResult: .failure(NSError(domain: "test", code: 1))
        )
        let store = PreAuthTermsAgreementStore(service: stub)

        await store.loadActiveVersion()

        #expect(store.activeVersion == nil)
        #expect(store.termsURL == PreAuthTermsAgreementStore.fallbackTermsURL)
        #expect(store.privacyURL == PreAuthTermsAgreementStore.fallbackPrivacyURL)
    }

    @Test func termsAcceptanceLogLevelsReflectSeverity() {
        #expect(TermsAcceptanceLogs.preAuthAgreementToggled.level == .info)
        #expect(TermsAcceptanceLogs.preAuthAgreementGated.level == .info)
        #expect(TermsAcceptanceLogs.acceptanceRecorded.level == .info)
        #expect(TermsAcceptanceLogs.postAuthGatePresented.level == .info)
        #expect(TermsAcceptanceLogs.postAuthGateAccepted.level == .info)
        #expect(TermsAcceptanceLogs.acceptanceRecordFailed.level == .error)
        #expect(TermsAcceptanceLogs.loadActiveVersionFailed.level == .error)
        #expect(TermsAcceptanceLogs.acceptanceCheckFailed.level == .error)
    }
}
