//
//  PaywallPurchaseUIState.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Derives paywall button / status copy from StoreKit loading flags (no StoreKit types).
enum PaywallPurchaseUIState {
    static func isStoreBusy(isPurchasing: Bool, isRestoring: Bool) -> Bool {
        isPurchasing || isRestoring
    }

    static func isPurchaseDisabled(isStoreBusy: Bool, hasProduct: Bool) -> Bool {
        isStoreBusy || !hasProduct
    }

    static func productLoadFailed(isLoadingProduct: Bool, hasProduct: Bool) -> Bool {
        !isLoadingProduct && !hasProduct
    }

    static func primaryButtonTitle(
        isPurchasing: Bool,
        isRestoring: Bool,
        priceLine: String
    ) -> String {
        if isPurchasing { return "Processing…" }
        if isRestoring { return "Restoring…" }
        return priceLine.isEmpty
            ? "Subscribe to Spot Pro"
            : "Subscribe to Spot Pro • \(priceLine)"
    }

    static func priceOrStatusLine(isLoadingProduct: Bool, priceLine: String) -> String {
        if isLoadingProduct { return "Loading subscription details…" }
        if !priceLine.isEmpty { return priceLine }
        return ""
    }

    static func productLoadMessage(productLoadFailed: Bool) -> String? {
        guard productLoadFailed else { return nil }
        return "We couldn’t load Spot Pro right now.\nPlease check your connection and try again."
    }
}
