//
//  SettingsViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SettingsViewLogs: SpotLog {
    case loadProfileFailed
    case usernameBlocked
    case verifyBeforeUpdateEmailFailed
    case saveFailed
    case saveSuccess
    case profilePhotoUploadStart
    case profilePhotoUploadNoUser
    case profilePhotoUpdateSupabaseFailed
    case profilePhotoUpdated
    case profilePhotoUploadFailed
    case deleteAccountTapped
    case deleteAccountBlockedMissingConfirmation

    var tag: String { "SettingsView" }
    var level: LogLevel {
        switch self {
        case .loadProfileFailed: return .error
        case .usernameBlocked: return .debug
        case .verifyBeforeUpdateEmailFailed: return .error
        case .saveFailed: return .error
        case .saveSuccess: return .info
        case .profilePhotoUploadStart: return .info
        case .profilePhotoUploadNoUser: return .error
        case .profilePhotoUpdateSupabaseFailed: return .error
        case .profilePhotoUpdated: return .info
        case .profilePhotoUploadFailed: return .error
        case .deleteAccountTapped: return .info
        case .deleteAccountBlockedMissingConfirmation: return .info
        }
    }
    var message: String {
        switch self {
        case .loadProfileFailed: return "Settings load profile failed"
        case .usernameBlocked: return "Username blocked"
        case .verifyBeforeUpdateEmailFailed: return "Settings verify before update email failed"
        case .saveFailed: return "Settings save failed"
        case .saveSuccess: return "Settings save success"
        case .profilePhotoUploadStart: return "Profile photo upload start"
        case .profilePhotoUploadNoUser: return "Profile photo upload: no user"
        case .profilePhotoUpdateSupabaseFailed: return "Profile photo Supabase update failed"
        case .profilePhotoUpdated: return "Profile photo updated"
        case .profilePhotoUploadFailed: return "Profile photo upload failed"
        case .deleteAccountTapped: return "Delete account tapped"
        case .deleteAccountBlockedMissingConfirmation: return "Delete account blocked: need confirmation and password"
        }
    }
}
