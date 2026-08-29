//
//  DeepLinkStateLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum DeepLinkStateLogs: SpotLog {
    case handlingDeepLink
    case handlingInitialUserActivity
    case ignoringDuplicateDeepLink
    case storedPendingDeepLink
    case storedPendingDeepLinkUnauthenticated
    case processingPendingDeepLink
    case deepLinkResult
    case fetchSpotFailed
    case clearedUserSessionState
    case handlingSubscriptionReturn
    case storedPendingSubscriptionReturn
    case storedPendingSubscriptionReturnUnauthenticated
    case noUserIdForSubscriptionCheck
    case userIsProShowingSuccess
    case userIsNotProDismissing
    case checkProStatusFailed

    var tag: String { "DeepLinkState" }
    var level: LogLevel {
        switch self {
        case .handlingDeepLink: return .info
        case .handlingInitialUserActivity: return .info
        case .ignoringDuplicateDeepLink: return .info
        case .storedPendingDeepLink: return .info
        case .storedPendingDeepLinkUnauthenticated: return .info
        case .processingPendingDeepLink: return .info
        case .deepLinkResult: return .info
        case .fetchSpotFailed: return .error
        case .clearedUserSessionState: return .info
        case .handlingSubscriptionReturn: return .info
        case .storedPendingSubscriptionReturn: return .info
        case .storedPendingSubscriptionReturnUnauthenticated: return .info
        case .noUserIdForSubscriptionCheck: return .error
        case .userIsProShowingSuccess: return .info
        case .userIsNotProDismissing: return .info
        case .checkProStatusFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .handlingDeepLink: return "Handling deep link"
        case .handlingInitialUserActivity: return "Handling initial user activity"
        case .ignoringDuplicateDeepLink: return "Ignoring duplicate deep link (debounced)"
        case .storedPendingDeepLink: return "Stored pending deep link for authenticated user"
        case .storedPendingDeepLinkUnauthenticated: return "Stored pending deep link for unauthenticated user"
        case .processingPendingDeepLink: return "Processing pending deep link"
        case .deepLinkResult: return "Deep link result"
        case .fetchSpotFailed: return "Failed to fetch spot"
        case .clearedUserSessionState: return "Cleared user session state"
        case .handlingSubscriptionReturn: return "Handling subscription return"
        case .storedPendingSubscriptionReturn: return "Stored pending subscription return"
        case .storedPendingSubscriptionReturnUnauthenticated: return "Stored pending subscription return for unauthenticated user"
        case .noUserIdForSubscriptionCheck: return "No user ID for subscription check"
        case .userIsProShowingSuccess: return "User is Pro, showing success screen"
        case .userIsNotProDismissing: return "User is not Pro, dismissing"
        case .checkProStatusFailed: return "Failed to check pro status"
        }
    }
}
