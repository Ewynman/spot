//
//  SubscriptionManagerRetryTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Testing
@testable import Spot

@MainActor
@Suite(.serialized)
struct SubscriptionManagerRetryTests {

    @Test func resetProductLoadStateClearsHasProductAndError() {
        let mgr = SubscriptionManager.shared
        mgr.hasProduct = true
        mgr.productLoadError = "Some prior error"

        mgr.resetProductLoadStateForRetry()

        #expect(mgr.hasProduct == false)
        #expect(mgr.productLoadError == nil)
    }

    @Test func resetProductLoadStateIsIdempotent() {
        let mgr = SubscriptionManager.shared
        mgr.resetProductLoadStateForRetry()
        mgr.resetProductLoadStateForRetry()
        mgr.resetProductLoadStateForRetry()

        #expect(mgr.hasProduct == false)
        #expect(mgr.productLoadError == nil)
    }

    @Test func userFacingProductLoadErrorIsRetryable() {
        // Paywall caption asks the user to retry — make sure the canonical
        // copy invites a retry rather than a dead-end.
        let copy = SubscriptionManager.userFacingProductLoadError
        #expect(copy.localizedCaseInsensitiveContains("try again") ||
                copy.localizedCaseInsensitiveContains("again"))
        #expect(!copy.isEmpty)
    }
}
