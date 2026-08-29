//
//  PaywallViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum PaywallViewLogs: SpotLog {
    case purchaseStarted
    case purchasePending
    case purchaseCancelled
    case purchaseFailed
    case restoreStarted
    case restoreFailed
    case manageSubscriptionsFailed

    var tag: String { "PaywallView" }
    var level: LogLevel {
        switch self {
        case .purchaseStarted: return .info
        case .purchasePending: return .info
        case .purchaseCancelled: return .info
        case .purchaseFailed: return .error
        case .restoreStarted: return .info
        case .restoreFailed: return .error
        case .manageSubscriptionsFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .purchaseStarted: return "User started App Store purchase"
        case .purchasePending: return "Purchase pending"
        case .purchaseCancelled: return "Purchase cancelled by user"
        case .purchaseFailed: return "Purchase failed"
        case .restoreStarted: return "User started App Store restore"
        case .restoreFailed: return "Restore failed"
        case .manageSubscriptionsFailed: return "Manage subscriptions failed"
        }
    }
}
