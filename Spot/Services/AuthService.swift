//
//  AuthService.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import Foundation
import Supabase

class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - Sign Up with Email-in-Use Handling

    func signUp(email: String, password: String, completion: @escaping (Result<AuthResult, Error>) -> Void) {
        let cleanEmail = AuthInputNormalizer.normalizeEmailLegacy(email)
        Task {
            do {
                _ = try await supabase.auth.signUp(email: cleanEmail, password: password)
                await SupabaseUserService.shared.syncCurrentUser()
                completion(.success(.success))
            } catch {
                if AuthErrorClassifier.isEmailInUse(error: error) {
                    SpotLogger.log(AuthServiceLogs.emailInUseDetected)
                    await MainActor.run {
                        AnalyticsService.shared.trackAuthEvent(Constants.Analytics.authEmailInUse, parameters: ["action": "detected"])
                    }
                    completion(.success(.emailInUse(.passwordAccount)))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String, completion: @escaping (Result<AuthResult, Error>) -> Void) {
        let cleanEmail = AuthInputNormalizer.normalizeEmailLegacy(email)
        Task {
            do {
                _ = try await supabase.auth.signIn(email: cleanEmail, password: password)
                completion(.success(.success))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanEmail = AuthInputNormalizer.normalizeEmailLegacy(email)
        Task {
            do {
                try await supabase.auth.resetPasswordForEmail(cleanEmail)
                SpotLogger.log(AuthServiceLogs.emailInUseReset)
                await MainActor.run {
                    AnalyticsService.shared.trackAuthEvent(Constants.Analytics.authEmailInUse, parameters: ["action": "reset"])
                    completion(.success(()))
                }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    /// Async/await wrapper for password reset.
    func resetPassword(email: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            resetPassword(email: email) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut(scope: .local)
    }

    // MARK: - Legacy/Callback API (to satisfy existing callers)

    /// Verify Supabase user row exists for current auth user
    func verifyUserExists(completion: @escaping (Bool) -> Void) {
        guard let uid = SpotAuthBridge.currentUserId else {
            SpotLogger.log(AuthServiceLogs.verifyUserExistsNoCurrentUser)
            completion(false)
            return
        }
        SpotLogger.log(AuthServiceLogs.verifyUserExistsChecking, details: ["uid": uid])
        Task {
            do {
                struct Row: Decodable { let id: UUID }
                guard let uuid = UUID(uuidString: uid) else {
                    completion(false)
                    return
                }
                let rows: [Row] = try await supabase
                    .from("users")
                    .select("id")
                    .eq("id", value: uuid)
                    .limit(1)
                    .execute()
                    .value
                let exists = !rows.isEmpty
                if !exists {
                    SpotLogger.log(AuthServiceLogs.missingUserProfileRow, details: ["userId": uid])
                    try? await supabase.auth.signOut(scope: .local)
                }
                completion(exists)
            } catch {
                SpotLogger.log(AuthServiceLogs.verifyUserExistsError, details: ["error": error.localizedDescription])
                completion(false)
            }
        }
    }

    /// Completion-style sign up used by existing UI
    func signUp(email: String, password: String, username: String, profileImageURL: String, isPrivate: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanEmail = AuthInputNormalizer.normalizeEmailLegacy(email)
        let cleanUsername = AuthInputNormalizer.normalizeUsernameLegacy(username)
        Task {
            do {
                _ = try await supabase.auth.signUp(
                    email: cleanEmail,
                    password: password,
                    data: [
                        "username": .string(cleanUsername),
                        "is_private": .bool(isPrivate)
                    ]
                )
                await SupabaseUserService.shared.syncCurrentUser()
                await MainActor.run {
                    AnalyticsService.shared.logEvent("user_signup", parameters: [
                        "email_verified": false,
                        "is_private": isPrivate
                    ])
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Completion-style sign in used by existing UI
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanEmail = AuthInputNormalizer.normalizeEmailLegacy(email)
        Task {
            do {
                _ = try await supabase.auth.signIn(email: cleanEmail, password: password)
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    /// Completion-style sign in that accepts either an email or username.
    /// If the identifier is not an email, this resolves the account email by username.
    func signIn(identifier: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let emailToUse: String
                if cleanIdentifier.contains("@") {
                    emailToUse = AuthInputNormalizer.normalizeEmailLegacy(cleanIdentifier)
                } else {
                    guard let resolved = try await resolveEmail(forUsername: cleanIdentifier) else {
                        throw NSError(
                            domain: "AuthService",
                            code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "No account found for that username."]
                        )
                    }
                    emailToUse = resolved
                }
                _ = try await supabase.auth.signIn(email: emailToUse, password: password)
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    private func resolveEmail(forUsername username: String) async throws -> String? {
        let normalized = AuthInputNormalizer.normalizeUsernameLowerLegacy(username)
        guard !normalized.isEmpty else { return nil }
        struct Params: Encodable { let p_username: String }
        let email: String? = try await supabase
            .rpc("resolve_login_email", params: Params(p_username: normalized))
            .execute()
            .value
        if let email, !email.isEmpty {
            return AuthInputNormalizer.normalizeEmailLegacy(email)
        }
        return nil
    }

    // MARK: - Reauthentication / Account management (callback style for existing VM)

    func reauthenticate(withPassword password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let user = try await supabase.auth.user()
                guard let email = user.email else {
                    throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
                }
                _ = try await supabase.auth.signIn(email: email, password: password)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func updateEmail(_ newEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await supabase.auth.update(user: UserAttributes(email: newEmail))
                SpotLogger.log(AuthServiceLogs.verificationEmailSentToNewAddress)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func updatePassword(_ newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await supabase.auth.update(user: UserAttributes(password: newPassword))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deleteAccount(password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    reauthenticate(withPassword: password) { result in
                        switch result {
                        case .success: cont.resume()
                        case .failure(let error): cont.resume(throwing: error)
                        }
                    }
                }
                try await performAccountDeletionAfterReauth(reauthMethod: "password")
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func deleteAccount(appleIDToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await reauthenticate(withAppleIDToken: appleIDToken)
                try await performAccountDeletionAfterReauth(reauthMethod: "apple")
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    private func reauthenticate(withAppleIDToken idToken: String) async throws {
        let userBefore = try await supabase.auth.user()
        _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        let userAfter = try await supabase.auth.user()
        guard userAfter.id == userBefore.id else {
            throw NSError(
                domain: "AuthService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "This Apple ID does not match your Spot account."]
            )
        }
    }

    private func performAccountDeletionAfterReauth(reauthMethod: String) async throws {
        SpotLogger.log(AuthServiceLogs.deleteAccountReauthenticated, details: ["method": reauthMethod])

        let session = try await supabase.auth.session
        let userId = session.user.id
        await purgeStorageForAccountDeletion(userId: userId)

        struct EmptyParams: Encodable {}
        SpotLogger.log(AuthServiceLogs.deleteAccountCallingRPC)
        try await runWithTimeout(seconds: 20) {
            _ = try await supabase.rpc("delete_my_account", params: EmptyParams()).execute()
        }
        SpotLogger.log(AuthServiceLogs.deleteAccountRPCFinished)

        do {
            try await supabase.auth.signOut()
        } catch {
            SpotLogger.log(AuthServiceLogs.deleteAccountSignOutAfterRPCFailed, details: [
                "error": error.localizedDescription
            ])
        }
    }

    private func runWithTimeout(seconds: UInt64, operation: @escaping @Sendable () async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw NSError(
                    domain: "AuthService",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: "Account deletion timed out. Please try again."]
                )
            }

            try await group.next()
            group.cancelAll()
        }
    }

    /// Removes objects under `{userId}/` in `avatars` and `spots` buckets (Postgres rows are wiped by RPC).
    private func purgeStorageForAccountDeletion(userId: UUID) async {
        let prefix = userId.uuidString.lowercased()
        for bucketId in ["avatars", "spots"] {
            do {
                let entries = try await supabase.storage
                    .from(bucketId)
                    .list(path: prefix)
                guard !entries.isEmpty else { continue }
                let paths = entries.map { "\(prefix)/\($0.name)" }
                let batchSize = 50
                var offset = 0
                while offset < paths.count {
                    let end = min(offset + batchSize, paths.count)
                    let batch = Array(paths[offset..<end])
                    _ = try await supabase.storage.from(bucketId).remove(paths: batch)
                    offset = end
                }
            } catch {
                SpotLogger.log(AuthServiceLogs.deleteAccountStoragePurgeFailed, details: [
                    "bucket": bucketId,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    // MARK: - Debug Functions (DEBUG only)

    #if DEBUG
    /// Delete Auth user by email (DEBUG only)
    func deleteAuthUserByEmail(_ email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        SpotLogger.log(AuthServiceLogs.deleteByEmailRequested, details: ["email": email])
        Task { @MainActor in
            AnalyticsService.shared.trackAuthEvent(Constants.Analytics.authDeleteByEmail, parameters: ["action": "requested", "email": email])
        }

        // This would call a Cloud Function in production
        // For now, just log the request and complete successfully
        SpotLogger.log(AuthServiceLogs.deleteAuthUserByEmailPlaceholder)

        // In production, this would be:
        // let functions = Functions.functions()
        // let data = ["email": email]
        // functions.httpsCallable("deleteAuthUserByEmail").call(data) { result, error in
        //     if let error = error {
        //         completion(.failure(error))
        //     } else {
        //         completion(.success(()))
        //     }
        // }

        SpotLogger.log(AuthServiceLogs.deleteByEmailSuccess)
        Task { @MainActor in
            AnalyticsService.shared.trackAuthEvent(Constants.Analytics.authDeleteByEmail, parameters: ["action": "result", "status": "ok"])
        }
        completion(.success(()))
    }
    #endif
}

// MARK: - Auth Result Types

enum AuthResult {
    case success
    case emailInUse(EmailInUseType)
}

enum EmailInUseType {
    case passwordAccount
    case federatedAccount(String)
    case inconsistentState

    var message: String {
        switch self {
        case .passwordAccount:
            return "An account with this email already exists. Please sign in or reset your password."
        case .federatedAccount(let provider):
            let providerName = provider.contains("apple.com") ? "Apple" : "Google"
            return "This email is already associated with a \(providerName) account. Please continue with \(providerName) or use a different email."
        case .inconsistentState:
            return "There was an issue with this email. Please try again or use a different email."
        }
    }

    var suggestedActions: [String] {
        switch self {
        case .passwordAccount:
            return ["Sign In", "Forgot Password", "Use Different Email"]
        case .federatedAccount(let provider):
            let providerName = provider.contains("apple.com") ? "Apple" : "Google"
            return ["Continue with \(providerName)", "Use Different Email"]
        case .inconsistentState:
            return ["Try Again", "Use Different Email"]
        }
    }
}
