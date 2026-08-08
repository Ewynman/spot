//
//  SubscriptionManagerStaticTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Coverage for the parts of SubscriptionManager that do not depend on a
//  live StoreKit session: published-state defaults, configured product
//  IDs, and the `PurchaseProResult` enum the UI switches on. Live purchase
//  / restore / entitlement flows are exercised via integration tests.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct SubscriptionManagerStaticTests {

    @Test func spotProProductsUsesAppStoreConnectProductID() {
        #expect(SpotProProducts.yearly == "spotPro")
        #expect(SpotProProducts.all == ["spotPro"])
    }

    @Test func sharedInstanceRequestsExactlySpotProProductId() {
        let mgr = SubscriptionManager.shared
        #expect(mgr.productIds == ["spotPro"])
    }

    @Test func sharedInstanceHasInitialFlags() {
        let mgr = SubscriptionManager.shared
        // These flags should never be left in a "busy" state when no API has
        // been called yet. We avoid asserting on hasProduct because the test
        // host may have already loaded the product in another test.
        #expect(mgr.isPurchasing == false)
        #expect(mgr.isRestoring == false)
    }

    @Test func purchaseResultEnumExposesPurchasedPendingAndCancelled() {
        // Compile-time check via exhaustive switch ensures these cases stay.
        let purchased = SubscriptionManager.PurchaseProResult.purchased(expirationDate: nil)
        let pending = SubscriptionManager.PurchaseProResult.pending
        let cancelled = SubscriptionManager.PurchaseProResult.userCancelled

        switch purchased {
        case .purchased(let date):
            #expect(date == nil)
        case .pending, .userCancelled:
            Issue.record("Expected .purchased")
        }

        switch pending {
        case .pending: break
        default: Issue.record("Expected .pending")
        }

        switch cancelled {
        case .userCancelled: break
        default: Issue.record("Expected .userCancelled")
        }
    }

    @Test func purchaseResultPurchasedCarriesExpirationDate() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = SubscriptionManager.PurchaseProResult.purchased(expirationDate: date)
        if case .purchased(let parsed) = result {
            #expect(parsed == date)
        } else {
            Issue.record("Expected .purchased")
        }
    }

    @Test func entitlementRefreshResultSeparatesOtherAccountFromInactive() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(SubscriptionManager.EntitlementRefreshResult.active(expirationDate: date).isActive)
        #expect(!SubscriptionManager.EntitlementRefreshResult.linkedToDifferentAccount.isActive)
        #expect(!SubscriptionManager.EntitlementRefreshResult.inactive.isActive)
        #expect(SubscriptionManager.EntitlementRefreshResult.linkedToDifferentAccount != .inactive)
    }

    @Test func purchaseErrorDescriptionIsHelpful() {
        let err: Error = SubscriptionPurchaseError.unknownPurchaseOutcome
        let description = (err as? LocalizedError)?.errorDescription ?? ""
        #expect(!description.isEmpty)
    }

    @Test func productLoadFallbackDoesNotExposeSetupInternals() {
        let message = SubscriptionManager.userFacingProductLoadError
        #expect(message == "Unable to load plan. Please try again.")
        #expect(!message.localizedCaseInsensitiveContains("Firebase"))
        #expect(!message.localizedCaseInsensitiveContains("StoreKit config"))
        #expect(!message.localizedCaseInsensitiveContains("No products found"))
    }
}
