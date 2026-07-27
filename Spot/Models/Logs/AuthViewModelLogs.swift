//
//  AuthViewModelLogs.swift
//  Spot
//
//  Log definitions for AuthViewModel.
//

import Foundation

enum AuthViewModelLogs: SpotLog {
    case authStateSignedIn
    case autoPromptPermissions
    case authStateSignedOut
    case authUserDeletedRemotely
    case signOutFailed
    case sessionRefreshFailed
    case refreshBlockedUsersFailed
    case refreshUserFlagsFailed
    case proStatusUpdated
    case proStatusUpdateFailed
    case bookmarkCapReached
    case verificationEmailSent
    case sendVerificationEmailFailed
    case emailVerified
    case checkVerificationStatusFailed
    case changeEmailVerifySent
    case emailChangeRequiresReauth
    case changeEmailError
    case usernameAvailabilityCheckFailed
    case userBlocked
    case userUnblocked

    var tag: String { "AuthViewModel" }
    var level: LogLevel {
        switch self {
        case .authStateSignedIn: return .debug
        case .autoPromptPermissions: return .info
        case .authStateSignedOut: return .debug
        case .authUserDeletedRemotely: return .info
        case .signOutFailed: return .error
        case .sessionRefreshFailed: return .error
        case .refreshBlockedUsersFailed: return .error
        case .refreshUserFlagsFailed: return .error
        case .proStatusUpdated: return .info
        case .proStatusUpdateFailed: return .error
        case .bookmarkCapReached: return .info
        case .verificationEmailSent: return .info
        case .sendVerificationEmailFailed: return .error
        case .emailVerified: return .info
        case .checkVerificationStatusFailed: return .error
        case .changeEmailVerifySent: return .info
        case .emailChangeRequiresReauth: return .debug
        case .changeEmailError: return .error
        case .usernameAvailabilityCheckFailed: return .error
        case .userBlocked: return .info
        case .userUnblocked: return .info
        }
    }
    var message: String {
        switch self {
        case .authStateSignedIn: return "Auth state changed: user signed in"
        case .autoPromptPermissions: return "Auto-prompting permissions after fresh install login"
        case .authStateSignedOut: return "Auth state changed: no user"
        case .authUserDeletedRemotely: return "Auth user deleted remotely; clearing local session"
        case .signOutFailed: return "Failed to sign out"
        case .sessionRefreshFailed: return "Failed to refresh expired session"
        case .refreshBlockedUsersFailed: return "Failed to refresh blocked users"
        case .refreshUserFlagsFailed: return "Failed to refresh user flags"
        case .proStatusUpdated: return "Pro status updated"
        case .proStatusUpdateFailed: return "Failed to set pro status"
        case .bookmarkCapReached: return "Bookmark cap reached"
        case .verificationEmailSent: return "Verification email sent"
        case .sendVerificationEmailFailed: return "Failed to send verification email"
        case .emailVerified: return "Email verified"
        case .checkVerificationStatusFailed: return "Failed to check verification status"
        case .changeEmailVerifySent: return "Change email verification sent"
        case .emailChangeRequiresReauth: return "Email change requires reauthentication"
        case .changeEmailError: return "Email change error"
        case .usernameAvailabilityCheckFailed: return "Username availability check failed"
        case .userBlocked: return "User blocked"
        case .userUnblocked: return "User unblocked"
        }
    }
}
