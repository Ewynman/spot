//
//  TokenService.swift
//  Spot
//
//  Created by Edward Wynman on 1/12/26.
//

import Foundation
import Security
import Supabase

class TokenService {
    static let shared = TokenService()

    private let tokenKeyBase = "com.spotapp.spot.supabaseAccessToken"
    private let expirationKeyBase = "com.spotapp.spot.tokenExpiration"
    private let tokenExpirationHours: TimeInterval = 24 // 24 hours

    private init() {}

    // MARK: - Token Management

    /// Get a valid Supabase access token, refreshing if necessary
    func getToken(completion: @escaping (Result<String, Error>) -> Void) {
        // Check if we have a cached token that's still valid
        if let cachedToken = getCachedToken(), !isTokenExpired() {
            SpotLogger.log(TokenServiceLogs.usingCachedToken)
            completion(.success(cachedToken))
            return
        }

        // Get fresh token from Supabase Auth session
        getFreshToken(completion: completion)
    }

    /// Force refresh the token
    func refreshToken(completion: @escaping (Result<String, Error>) -> Void) {
        SpotLogger.log(TokenServiceLogs.forcingTokenRefresh)
        getFreshToken(completion: completion)
    }

    /// Clear stored tokens (useful for logout)
    func clearTokens() {
        deleteFromKeychain(key: scopedKey(baseKey: tokenKeyBase))
        deleteFromKeychain(key: scopedKey(baseKey: expirationKeyBase))
        SpotLogger.log(TokenServiceLogs.clearedStoredTokens)
    }

    /// Clears local auth/session state if app switched between Supabase projects.
    /// Returns true when an incompatible prior project was detected and cleared.
    func enforceProjectSessionIsolationIfNeeded() async -> Bool {
        let defaults = UserDefaults.standard
        let previousProjectRef = defaults.string(forKey: Constants.UserDefaultsKeys.lastSupabaseProjectReference)
        let currentProjectRef = SupabaseConfiguration.load().projectRef

        defer {
            defaults.set(currentProjectRef, forKey: Constants.UserDefaultsKeys.lastSupabaseProjectReference)
        }

        guard shouldResetSession(previousProjectRef: previousProjectRef, currentProjectRef: currentProjectRef) else {
            return false
        }

        SpotLogger.log(
            TokenServiceLogs.projectReferenceChanged,
            details: ["from": previousProjectRef ?? "none", "to": currentProjectRef]
        )
        defaults.set("project_reference_changed", forKey: Constants.UserDefaultsKeys.supabaseSessionResetReason)

        clearTokens()
        do {
            try await supabase.auth.signOut(scope: .local)
        } catch {
            SpotLogger.log(TokenServiceLogs.failedToClearIncompatibleSession, details: ["error": error.localizedDescription])
        }
        SpotAuthBridge.setSessionUser(id: nil, email: nil)
        AuthVerificationRecoveryStore.shared.clear()
        await MainActor.run {
            FeedRepository.shared.reset()
            DeepLinkState.shared.clearUserSession()
        }
        return true
    }

    // MARK: - Private Methods

    private func getFreshToken(completion: @escaping (Result<String, Error>) -> Void) {
        guard SpotAuthBridge.currentUserId != nil else {
            let error = NSError(domain: "TokenService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            SpotLogger.log(TokenServiceLogs.noAuthenticatedUser)
            completion(.failure(error))
            return
        }

        Task { [weak self] in
            do {
                let session = try await supabase.auth.session
                let token = session.accessToken
                self?.cacheToken(token)
                SpotLogger.log(TokenServiceLogs.gotFreshToken)
                completion(.success(token))
            } catch {
                SpotLogger.log(TokenServiceLogs.failedToGetIdToken, details: ["error": error.localizedDescription])
                completion(.failure(error))
            }
        }
    }

    private func cacheToken(_ token: String) {
        let expirationDate = Date().addingTimeInterval(tokenExpirationHours * 3600)

        saveToKeychain(key: scopedKey(baseKey: tokenKeyBase), value: token)
        saveToKeychain(key: scopedKey(baseKey: expirationKeyBase), value: String(expirationDate.timeIntervalSince1970))
    }

    private func getCachedToken() -> String? {
        return getFromKeychain(key: scopedKey(baseKey: tokenKeyBase))
    }

    private func isTokenExpired() -> Bool {
        guard let expirationString = getFromKeychain(key: scopedKey(baseKey: expirationKeyBase)),
              let expirationTimeInterval = TimeInterval(expirationString) else {
            return true // Consider expired if we can't read expiration
        }

        let expirationDate = Date(timeIntervalSince1970: expirationTimeInterval)
        return Date() >= expirationDate
    }

    func scopedKey(baseKey: String, projectRef: String = SupabaseConfiguration.load().projectRef) -> String {
        "\(baseKey).\(projectRef)"
    }

    func shouldResetSession(previousProjectRef: String?, currentProjectRef: String) -> Bool {
        guard let previousProjectRef, !previousProjectRef.isEmpty else { return false }
        return previousProjectRef != currentProjectRef
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            SpotLogger.log(TokenServiceLogs.failedToSaveToKeychain, details: ["key": key, "status": status])
        }
    }

    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }

        return nil
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
