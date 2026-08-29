//
//  SubscriptionManagerLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SubscriptionManagerLogs: SpotLog {
    case productLoadStarted
    case productLoadSucceeded
    case noMatchingProduct
    case ensureProductLoadedFailed
    case unhandledPurchaseResult
    case restoreSyncCompleted
    case entitlementRefreshFoundPro
    case entitlementRefreshNoPro
    case entitlementLinkedToDifferentAccount
    case transactionUpdateUnverified
    case transactionUpdateVerifiedProFinishing
    case transactionUpdateFinishingNonPro

    var tag: String { "SubscriptionManager" }
    var level: LogLevel {
        switch self {
        case .productLoadStarted: return .info
        case .productLoadSucceeded: return .info
        case .noMatchingProduct: return .error
        case .ensureProductLoadedFailed: return .error
        case .unhandledPurchaseResult: return .error
        case .restoreSyncCompleted: return .info
        case .entitlementRefreshFoundPro: return .info
        case .entitlementRefreshNoPro: return .info
        case .entitlementLinkedToDifferentAccount: return .error
        case .transactionUpdateUnverified: return .error
        case .transactionUpdateVerifiedProFinishing: return .info
        case .transactionUpdateFinishingNonPro: return .debug
        }
    }
    var message: String {
        switch self {
        case .productLoadStarted: return "StoreKit: Loading Spot Pro product"
        case .productLoadSucceeded: return "StoreKit: Loaded Spot Pro product"
        case .noMatchingProduct: return "StoreKit: No matching product found"
        case .ensureProductLoadedFailed: return "StoreKit ensureProductLoaded failed"
        case .unhandledPurchaseResult: return "StoreKit: Unhandled Product.PurchaseResult"
        case .restoreSyncCompleted: return "StoreKit: Restore sync completed"
        case .entitlementRefreshFoundPro: return "StoreKit: Entitlement refresh found active Pro"
        case .entitlementRefreshNoPro: return "StoreKit: Entitlement refresh found no active Pro"
        case .entitlementLinkedToDifferentAccount:
            return "StoreKit: Active Pro entitlement belongs to another app account"
        case .transactionUpdateUnverified:
            return "StoreKit: Unverified transaction in Transaction.updates"
        case .transactionUpdateVerifiedProFinishing:
            return "StoreKit: Verified Pro transaction in updates; finishing"
        case .transactionUpdateFinishingNonPro:
            return "StoreKit: Finishing transaction in updates (non-Pro product)"
        }
    }
}
