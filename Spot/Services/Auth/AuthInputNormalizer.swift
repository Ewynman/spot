//
//  AuthInputNormalizer.swift
//  Spot
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Pure helpers for the auth pipeline so input normalization and error
//  classification can be exercised in isolation. AuthService routes its
//  inline string handling through these helpers to keep behavior identical.
//

import Foundation

enum AuthInputNormalizer {
    /// Normalizes user-entered email by trimming surrounding whitespace and
    /// lowercasing. Supabase treats emails case-insensitively but persists the
    /// exact casing it receives, so callers should always normalize first.
    /// Throws if email fails validation.
    static func normalizeEmail(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if let error = InputValidation.validateEmail(trimmed) {
            throw NSError(domain: "AuthInputNormalizer", code: 400, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        return trimmed
    }
    
    /// Legacy non-throwing variant for backward compatibility.
    /// Use the throwing variant in new code.
    static func normalizeEmailLegacy(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Trims user-entered username without changing case. Username casing is
    /// preserved for display, while `username_lower` is computed separately
    /// for case-insensitive uniqueness checks.
    /// Throws if username fails validation.
    static func normalizeUsername(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let error = InputValidation.validateUsername(trimmed) {
            throw NSError(domain: "AuthInputNormalizer", code: 400, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        return trimmed
    }
    
    /// Legacy non-throwing variant for backward compatibility.
    /// Use the throwing variant in new code.
    static func normalizeUsernameLegacy(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lowercased copy of a normalized username for case-insensitive lookups.
    /// Throws if username fails validation.
    static func normalizeUsernameLower(_ raw: String) throws -> String {
        try normalizeUsername(raw).lowercased()
    }
    
    /// Legacy non-throwing variant for backward compatibility.
    /// Use the throwing variant in new code.
    static func normalizeUsernameLowerLegacy(_ raw: String) -> String {
        normalizeUsernameLegacy(raw).lowercased()
    }
}

enum AuthErrorClassifier {
    /// Heuristic match for "email already exists" errors returned by Supabase
    /// auth. Supabase doesn't surface a stable error code, so we lowercase the
    /// localized description and look for any of the known phrases.
    static func isEmailInUse(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("already")
            || lower.contains("exists")
            || lower.contains("registered")
    }

    /// Convenience overload that pulls the localized description from an Error
    /// before classifying.
    static func isEmailInUse(error: Error) -> Bool {
        isEmailInUse(error.localizedDescription)
    }

    /// Detects the "email already registered" case for a Supabase email
    /// sign-up response. With email-enumeration protection enabled, Supabase
    /// does not throw for an existing email: it returns HTTP 200 with no
    /// session and an empty `identities` array (and sends no confirmation
    /// email). Callers must treat this as an existing account instead of
    /// routing the user to the email-verification screen.
    ///
    /// - Parameters:
    ///   - hasSession: Whether the sign-up response contained a session.
    ///   - identityCount: Number of identities on the returned user
    ///     (pass `0` when `identities` is `nil`).
    static func isExistingAccountSignup(hasSession: Bool, identityCount: Int) -> Bool {
        !hasSession && identityCount == 0
    }
}
