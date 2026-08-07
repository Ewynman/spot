//
//  ConstantsLegalURLTests.swift
//  SpotTests
//

import Foundation
import Testing
@testable import Spot

struct ConstantsLegalURLTests {

    @Test func legalURLsMatchAppStoreRegisteredHosts() {
        #expect(Constants.Legal.termsURL.absoluteString == Constants.Legal.termsURLString)
        #expect(Constants.Legal.privacyURL.absoluteString == Constants.Legal.privacyURLString)
        #expect(Constants.Legal.termsURL.host == "spotapp.online")
        #expect(Constants.Legal.privacyURL.host == "spotapp.online")
    }

    @Test func preAuthFallbackURLsMatchLegalConstants() {
        #expect(PreAuthTermsAgreementStore.fallbackTermsURL == Constants.Legal.termsURL)
        #expect(PreAuthTermsAgreementStore.fallbackPrivacyURL == Constants.Legal.privacyURL)
    }
}
