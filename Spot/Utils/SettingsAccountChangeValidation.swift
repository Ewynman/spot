//
//  SettingsAccountChangeValidation.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Pre-save field gates for Settings account / security forms.
enum SettingsAccountChangeValidation {
    enum UsernameGate: Equatable {
        case ok
        case empty
    }

    enum PasswordChangeGate: Equatable {
        case ok
        case mismatch
        case invalidNewPassword(String)
        case currentPasswordRequired
    }

    enum DeleteAccountGate: Equatable {
        case ok
        case missingPasswordConfirmation
        case missingAppleConfirmation
    }

    static func usernameGate(_ username: String) -> UsernameGate {
        username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .ok
    }

    static let emptyUsernameMessage = "Username cannot be empty"
    static let passwordMismatchMessage = "Passwords do not match."
    static let currentPasswordRequiredForEmailOrPassword =
        "Current password is required for email or password changes."
    static let currentPasswordRequiredForPassword =
        "Current password is required for password changes."
    static let currentPasswordRequiredForEmail =
        "Current password is required for email changes."
    static let deleteNeedsPasswordConfirmation =
        "Turn on the confirmation switch and enter your password to delete your account."
    static let deleteNeedsAppleConfirmation =
        "Turn on the confirmation switch before deleting your account."

    /// Validates optional password-change fields when either new or confirm is non-empty.
    static func passwordChangeGate(
        newPassword: String,
        confirmPassword: String,
        currentPassword: String,
        requireCurrentPassword: Bool
    ) -> PasswordChangeGate {
        let changing = !newPassword.isEmpty || !confirmPassword.isEmpty
        guard changing else { return .ok }
        guard newPassword == confirmPassword else { return .mismatch }
        switch PasswordValidator.validate(newPassword) {
        case .ok:
            break
        case .failure(let message):
            return .invalidNewPassword(message)
        }
        if requireCurrentPassword,
           currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .currentPasswordRequired
        }
        return .ok
    }

    /// Email/password change path: require current password when either changes.
    static func requiresCurrentPassword(
        isEmailChange: Bool,
        isPasswordChange: Bool,
        currentPassword: String
    ) -> Bool {
        (isEmailChange || isPasswordChange)
            && currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func deleteAccountGate(
        confirmDelete: Bool,
        deletePassword: String,
        reauth: DeleteReauth
    ) -> DeleteAccountGate {
        switch reauth {
        case .password:
            return (confirmDelete && !deletePassword.isEmpty) ? .ok : .missingPasswordConfirmation
        case .apple:
            return confirmDelete ? .ok : .missingAppleConfirmation
        }
    }

    enum DeleteReauth {
        case password
        case apple
    }
}
