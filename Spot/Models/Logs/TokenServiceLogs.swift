//
//  TokenServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum TokenServiceLogs: SpotLog {
    case usingCachedToken
    case forcingTokenRefresh
    case clearedStoredTokens
    case noAuthenticatedUser
    case failedToGetIdToken
    case noTokenReceived
    case gotFreshToken
    case failedToSaveToKeychain
    case projectReferenceChanged
    case failedToClearIncompatibleSession

    var tag: String { "TokenService" }
    var level: LogLevel {
        switch self {
        case .usingCachedToken: return .debug
        case .forcingTokenRefresh: return .debug
        case .clearedStoredTokens: return .debug
        case .noAuthenticatedUser: return .error
        case .failedToGetIdToken: return .error
        case .noTokenReceived: return .error
        case .gotFreshToken: return .debug
        case .failedToSaveToKeychain: return .error
        case .projectReferenceChanged: return .info
        case .failedToClearIncompatibleSession: return .error
        }
    }
    var message: String {
        switch self {
        case .usingCachedToken: return "Using cached token"
        case .forcingTokenRefresh: return "Forcing token refresh"
        case .clearedStoredTokens: return "Cleared stored tokens"
        case .noAuthenticatedUser: return "No authenticated user"
        case .failedToGetIdToken: return "Failed to get ID token"
        case .noTokenReceived: return "No token received from Supabase Auth"
        case .gotFreshToken: return "Got fresh token from Supabase Auth"
        case .failedToSaveToKeychain: return "Failed to save to keychain"
        case .projectReferenceChanged: return "Supabase project changed; clearing incompatible local session state"
        case .failedToClearIncompatibleSession: return "Failed to clear incompatible Supabase session during project switch"
        }
    }
}
