//
//  SubscriptionPurchaseErrorTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/24/2026
//

import Foundation
import Testing
@testable import Spot

struct SubscriptionPurchaseErrorTests {

    @Test func unknownPurchaseOutcomeHasDescription() {
        let err = SubscriptionPurchaseError.unknownPurchaseOutcome
        let text = err.errorDescription ?? ""
        #expect(!text.isEmpty)
        #expect(text.localizedCaseInsensitiveContains("Unexpected"))
    }

    @Test func nonProTransactionHasGenericDescription() {
        let err = SubscriptionPurchaseError.nonProTransaction
        let text = err.errorDescription ?? ""
        #expect(!text.isEmpty)
        #expect(!text.localizedCaseInsensitiveContains("StoreKit config"))
        #expect(!text.localizedCaseInsensitiveContains("No products found"))
    }

    @Test func linkedDifferentAccountExplainsOwnershipMismatch() {
        let err = SubscriptionPurchaseError.subscriptionLinkedToDifferentAccount
        let text = err.errorDescription ?? ""
        #expect(text.localizedCaseInsensitiveContains("another Spot account"))
    }
}
