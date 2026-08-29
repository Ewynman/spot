//
//  AuthServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum AuthServiceLogs: SpotLog {
    case emailInUseDetected
    case emailInUseReset
    case verifyUserExistsNoCurrentUser
    case verifyUserExistsChecking
    case verifyUserExistsError
    case missingUserProfileRow
    case verificationEmailSentToNewAddress
    case deleteByEmailRequested
    case deleteAuthUserByEmailPlaceholder
    case deleteByEmailSuccess
    case deleteAccountStoragePurgeFailed
    case deleteAccountSignOutAfterRPCFailed
    case deleteAccountReauthenticated
    case deleteAccountCallingRPC
    case deleteAccountRPCFinished

    var tag: String { "AuthService" }
    var level: LogLevel {
        switch self {
        case .emailInUseDetected: return .info
        case .emailInUseReset: return .info
        case .verifyUserExistsNoCurrentUser: return .debug
        case .verifyUserExistsChecking: return .debug
        case .verifyUserExistsError: return .error
        case .missingUserProfileRow: return .error
        case .verificationEmailSentToNewAddress: return .info
        case .deleteByEmailRequested: return .info
        case .deleteAuthUserByEmailPlaceholder: return .debug
        case .deleteByEmailSuccess: return .info
        case .deleteAccountStoragePurgeFailed: return .info
        case .deleteAccountSignOutAfterRPCFailed: return .info
        case .deleteAccountReauthenticated: return .info
        case .deleteAccountCallingRPC: return .info
        case .deleteAccountRPCFinished: return .info
        }
    }
    var message: String {
        switch self {
        case .emailInUseDetected: return "Email already in use detected"
        case .emailInUseReset: return "Email in use flag reset"
        case .verifyUserExistsNoCurrentUser: return "verifyUserExists: no current user"
        case .verifyUserExistsChecking: return "verifyUserExists: checking user"
        case .verifyUserExistsError: return "verifyUserExists error"
        case .missingUserProfileRow: return "Missing users profile row, signing out"
        case .verificationEmailSentToNewAddress: return "Verification email sent to new address"
        case .deleteByEmailRequested: return "Delete auth user by email requested"
        case .deleteAuthUserByEmailPlaceholder: return "deleteAuthUserByEmail: implement Cloud Function"
        case .deleteByEmailSuccess: return "Delete auth user by email succeeded"
        case .deleteAccountStoragePurgeFailed: return "Account delete: storage purge failed (non-fatal)"
        case .deleteAccountSignOutAfterRPCFailed: return "Account delete: sign out after RPC failed; client should clear local session"
        case .deleteAccountReauthenticated: return "Account delete: password re-auth succeeded; calling delete_my_account"
        case .deleteAccountCallingRPC: return "Account delete: invoking delete_my_account RPC"
        case .deleteAccountRPCFinished: return "Account delete: RPC finished"
        }
    }
}
