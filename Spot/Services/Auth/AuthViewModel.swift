//
//  AuthViewModel.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import Foundation
import UIKit
import Supabase
import AuthenticationServices

enum UsernameAvailabilityOutcome: Equatable {
    case available
    case taken
    case unavailable
}

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var userId: String?
    @Published var isEmailVerified: Bool = false
    /// True when signup finished without a session (email confirmation / OTP pending).
    @Published var awaitingEmailVerification: Bool = false
    @Published var verificationEmailMaskSource: String = ""
    @Published var emailResendAvailableAt: Date?
    @Published var likedSpots: [String] = []
    @Published var bookmarkedSpots: [String] = []
    @Published var blockedUsers: [String] = []
    @Published var isPro: Bool = false
    @Published var proUntil: Date? = nil
    @Published var customVibeTags: [String] = []
    /// Cached profile image URL for the signed-in user. Used by the map
    /// user-location avatar marker so we don't refetch the profile row every
    /// time the map appears.
    @Published var currentUserProfileImageURL: String?
    /// Cached username for the signed-in user (used as initials fallback for
    /// the map avatar marker).
    @Published var currentUserUsername: String?

    private var supabaseAuthTask: Task<Void, Never>?
    private var sessionRefreshTask: Task<Void, Never>?

    init() {
        restoreVerificationRecovery()
        #if DEBUG
        if SpotLaunchConfiguration.uiTestAuthBootstrap == .loggedIn {
            Task { @MainActor in
                self.configureUITestSyntheticAuthIfNeeded()
            }
        }
        #endif
        listenToSupabaseAuthState()
    }

    deinit {
        supabaseAuthTask?.cancel()
        sessionRefreshTask?.cancel()
    }

    private var previousUserId: String?
    /// True while `delete_my_account` is in flight (password re-auth triggers `.signedIn`; skip profile sync / feed refreshes).
    private var accountDeletionInProgress = false
    /// When true, UI tests use a synthetic session; ignore Supabase auth stream updates (DEBUG bootstrap only).
    private var uiTestSyntheticSessionActive = false

    private func listenToSupabaseAuthState() {
        supabaseAuthTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.configureUITestSyntheticAuthIfNeeded()
            for await (event, session) in supabase.auth.authStateChanges {
                if self.uiTestSyntheticSessionActive { continue }
                self.applySupabaseAuthChange(event: event, session: session)
            }
        }
    }

    @MainActor
    private func configureUITestSyntheticAuthIfNeeded() {
        #if DEBUG
        guard SpotLaunchConfiguration.uiTestAuthBootstrap == .loggedIn else { return }
        uiTestSyntheticSessionActive = true
        userId = SpotLaunchConfiguration.uiTestSyntheticUserId
        isAuthenticated = true
        isEmailVerified = true
        isLoading = false
        awaitingEmailVerification = false
        isPro = SpotLaunchConfiguration.uiTestUserIsPro
        proUntil = nil
        if let reauth = SpotLaunchConfiguration.uiTestAccountDeletionReauth {
            accountDeletionReauthMethod = reauth
        }
        #endif
    }

    @MainActor
    private func applySupabaseAuthChange(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            guard let session else {
                clearSignedOutState(preservePendingVerification: awaitingEmailVerification)
                return
            }
            if session.isExpired {
                refreshExpiredSessionIfNeeded()
                return
            }
            sessionRefreshTask?.cancel()
            sessionRefreshTask = nil
            let user = session.user
            AuthVerificationRecoveryStore.shared.clear()
            SpotLogger.log(AuthViewModelLogs.authStateSignedIn, details: ["uid": user.id.uuidString])

            let isNewLogin = previousUserId == nil && userId == nil
            userId = user.id.uuidString
            SpotAuthBridge.setSessionUser(id: user.id.uuidString, email: user.email, emailVerified: user.emailConfirmedAt != nil)
            isAuthenticated = true
            isLoading = false
            isEmailVerified = user.emailConfirmedAt != nil
            awaitingEmailVerification = false
            verificationEmailMaskSource = user.email ?? verificationEmailMaskSource
            saveAccountHint(for: session)

            AnalyticsService.shared.setUserId(user.id.uuidString)

            let suppressSideEffects = accountDeletionInProgress
            if !suppressSideEffects {
                if isNewLogin {
                    AnalyticsService.shared.logEvent("user_login", parameters: [
                        "email_verified": user.emailConfirmedAt != nil
                    ])
                }
                refreshUserSpotLists()
                refreshBlockedUsers()
                refreshUserFlags()
                Task {
                    await SupabaseUserService.shared.syncCurrentUser()
                }
            }
            previousUserId = user.id.uuidString

        case .signedOut:
            SpotLogger.log(AuthViewModelLogs.authStateSignedOut)
            clearSignedOutState()
            Task { await teardownSessionCaches() }

        case .userDeleted:
            SpotLogger.log(AuthViewModelLogs.authUserDeletedRemotely)
            AuthAccountHintStore.shared.clear()
            clearSignedOutState()
            Task { await teardownSessionCaches() }

        case .passwordRecovery, .mfaChallengeVerified:
            break
        }
    }

    @MainActor
    private func clearSignedOutState(preservePendingVerification: Bool = false) {
        AnalyticsService.shared.setUserId(nil)
        SpotAuthBridge.setSessionUser(id: nil, email: nil)
        userId = nil
        isAuthenticated = false
        isLoading = false
        isEmailVerified = false
        if !preservePendingVerification {
            awaitingEmailVerification = false
            emailResendAvailableAt = nil
            verificationEmailMaskSource = ""
        }
        likedSpots = []
        bookmarkedSpots = []
        blockedUsers = []
        isPro = false
        proUntil = nil
        customVibeTags = []
        currentUserProfileImageURL = nil
        currentUserUsername = nil
        previousUserId = nil
        PreAuthTermsAgreementStore.shared.reset()
    }

    private func restoreVerificationRecovery() {
        guard let recovery = AuthVerificationRecoveryStore.shared.load() else { return }
        pendingVerificationEmail = recovery.email
        pendingVerificationUserId = recovery.userId
        verificationEmailMaskSource = recovery.email
        awaitingEmailVerification = true
    }

    @MainActor
    private func refreshExpiredSessionIfNeeded() {
        guard sessionRefreshTask == nil else { return }
        isLoading = true
        sessionRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.sessionRefreshTask = nil }
            do {
                _ = try await supabase.auth.refreshSession()
            } catch {
                SpotLogger.log(
                    AuthViewModelLogs.sessionRefreshFailed,
                    details: ["error": error.localizedDescription]
                )
                TokenService.shared.clearTokens()
                await self.teardownSessionCaches()
                self.clearSignedOutState(
                    preservePendingVerification: self.awaitingEmailVerification
                )
            }
        }
    }

    private func saveAccountHint(for session: Session) {
        let user = session.user
        let provider: AuthAccountProvider =
            user.appMetadata["provider"]?.stringValue?.lowercased() == "apple" ? .apple : .email
        let username = user.userMetadata["username"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let displayLabel: String
        if let username, !username.isEmpty {
            displayLabel = "@\(username)"
        } else {
            displayLabel = email?.split(separator: "@").first.map(String.init) ?? "Your Spot account"
        }
        AuthAccountHintStore.shared.save(
            AuthAccountHint(
                email: email,
                displayLabel: displayLabel,
                provider: provider,
                lastSignedInAt: Date()
            )
        )
    }

    /// Feed, deep links, and privacy cache — call after sign-out or account deletion.
    private func teardownSessionCaches() async {
        await MainActor.run {
            FeedRepository.shared.reset()
            DeepLinkState.shared.clearUserSession()
        }
        await AuthorPrivacyCache.shared.clear()
    }

    func signUp(email: String, password: String, username: String, profileImageURL: String, isPrivate: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        AuthService.shared.signUp(
            email: email,
            password: password,
            username: username,
            profileImageURL: profileImageURL,
            isPrivate: isPrivate,
            completion: completion
        )
    }

    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        AuthService.shared.signIn(email: email, password: password, completion: completion)
    }

    /// Completes native Apple auth by exchanging the Apple identity token with Supabase.
    /// Optionally persists the full name into auth metadata when Apple provides it (first consent only).
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        if let fullName {
            var parts: [String] = []
            if let given = fullName.givenName, !given.isEmpty { parts.append(given) }
            if let middle = fullName.middleName, !middle.isEmpty { parts.append(middle) }
            if let family = fullName.familyName, !family.isEmpty { parts.append(family) }

            if !parts.isEmpty {
                let full = parts.joined(separator: " ")
                _ = try? await supabase.auth.update(
                    user: UserAttributes(
                        data: [
                            "full_name": .string(full),
                            "given_name": .string(fullName.givenName ?? ""),
                            "family_name": .string(fullName.familyName ?? "")
                        ]
                    )
                )
            }
        }

        await SupabaseUserService.shared.syncCurrentUser()
    }

    @MainActor func signOut() {
        Task {
            do {
                try await supabase.auth.signOut(scope: .local)
            } catch {
                SpotLogger.log(AuthViewModelLogs.signOutFailed, details: ["error": error.localizedDescription])
            }
            TokenService.shared.clearTokens()
            AuthVerificationRecoveryStore.shared.clear()
            await teardownSessionCaches()
            await MainActor.run {
                self.clearSignedOutState()
            }
        }
    }

    func refreshUserSpotLists() {
        guard userId != nil else { return }
        UserSpotService.shared.fetchUserSpotLists { [weak self] liked, bookmarked in
            DispatchQueue.main.async {
                self?.likedSpots = liked
                self?.bookmarkedSpots = bookmarked
            }
        }
        // Also fetch blocked users
        refreshBlockedUsers()
    }

    func refreshBlockedUsers() {
        Task { await syncBlockedUsersFromServer() }
    }

    /// Fetches `user_blocks` for the signed-in user and replaces `blockedUsers`.
    private func syncBlockedUsersFromServer() async {
        guard let userId = userId, let uid = UUID(uuidString: userId) else { return }
        do {
            struct Row: Decodable { let blocked_user_id: UUID }
            let rows: [Row] = try await supabase
                .from("user_blocks")
                .select("blocked_user_id")
                .eq("blocker_id", value: uid)
                .execute()
                .value
            let blocked = rows.map { $0.blocked_user_id.uuidString }
            await MainActor.run {
                self.blockedUsers = blocked
            }
        } catch {
            SpotLogger.log(AuthViewModelLogs.refreshBlockedUsersFailed, details: ["error": error.localizedDescription])
        }
    }

    // MARK: - User flags (Pro)
    func refreshUserFlags() {
        guard let userId = userId, let uid = UUID(uuidString: userId) else { return }
        Task {
            do {
                struct FlagsRow: Decodable {
                    let is_pro: Bool
                    let pro_until: String?
                    let profile_image_url: String?
                    let username: String?
                }
                let row: FlagsRow = try await supabase
                    .from("users")
                    .select("is_pro,pro_until,profile_image_url,username")
                    .eq("id", value: uid)
                    .single()
                    .execute()
                    .value

                let proUntilDate = SpotSupabaseRepository.parseTimestamptz(row.pro_until)
                let isProValue: Bool
                if let until = proUntilDate {
                    isProValue = until > Date()
                } else {
                    isProValue = row.is_pro
                }

                await MainActor.run {
                    self.isPro = isProValue
                    self.proUntil = proUntilDate
                    if isProValue, let uidStr = self.userId {
                        self.customVibeTags = VibeTagService.savedCustomTagNames(forUserId: uidStr)
                    } else {
                        self.customVibeTags = []
                    }
                    self.currentUserProfileImageURL = row.profile_image_url
                    self.currentUserUsername = row.username
                }
            } catch {
                SpotLogger.log(AuthViewModelLogs.refreshUserFlagsFailed, details: ["error": error.localizedDescription])
            }
        }
    }

    func setProActive(_ active: Bool, proUntil: Date? = nil) async {
        guard let userId, let uid = UUID(uuidString: userId) else { return }
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let proUntilString: String? = {
                if active, let expiry = proUntil { return formatter.string(from: expiry) }
                if !active { return nil }
                return nil
            }()

            struct ProPatch: Encodable {
                let is_pro: Bool
                let pro_until: String?
            }

            try await supabase
                .from("users")
                .update(ProPatch(is_pro: active, pro_until: proUntilString))
                .eq("id", value: uid)
                .execute()

            await MainActor.run {
                self.isPro = active
                self.proUntil = active ? proUntil : nil
            }
            SpotLogger.log(AuthViewModelLogs.proStatusUpdated, details: ["active": active, "proUntil": proUntil?.description ?? "nil"])
        } catch {
            SpotLogger.log(AuthViewModelLogs.proStatusUpdateFailed, details: ["error": error.localizedDescription])
        }
    }

    func likeSpot(_ spotId: String) {
        UserSpotService.shared.likeSpot(spotId: spotId) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    if !(self?.likedSpots.contains(spotId) ?? false) {
                        self?.likedSpots.append(spotId)
                    }
                }
            }
        }
    }
    func unlikeSpot(_ spotId: String) {
        UserSpotService.shared.unlikeSpot(spotId: spotId) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.likedSpots.removeAll { $0 == spotId }
                }
            }
        }
    }
    func bookmarkSpot(_ spotId: String) {
        // Free users capped at 50 bookmarks
        if !isPro && bookmarkedSpots.count >= 50 {
            SpotLogger.log(AuthViewModelLogs.bookmarkCapReached, details: ["cap": 50])
            NotificationCenter.default.post(name: .showPaywall, object: nil)
            return
        }
        UserSpotService.shared.bookmarkSpot(spotId: spotId) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    if !(self?.bookmarkedSpots.contains(spotId) ?? false) {
                        self?.bookmarkedSpots.append(spotId)
                    }
                }
            }
        }
    }
    func unbookmarkSpot(_ spotId: String) {
        UserSpotService.shared.unbookmarkSpot(spotId: spotId) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.bookmarkedSpots.removeAll { $0 == spotId }
                }
            }
        }
    }

    // MARK: - Settings Updates (Supabase `public.users` + auth metadata)
    func updateUsername(_ username: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = userId, let uid = UUID(uuidString: userId) else {
            completion(.failure(NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user"])))
            return
        }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLower = trimmed.lowercased()
        Task {
            do {
                struct NameRow: Decodable { let username_lower: String }
                let current: NameRow = try await supabase
                    .from("users")
                    .select("username_lower")
                    .eq("id", value: uid)
                    .single()
                    .execute()
                    .value

                if newLower != current.username_lower {
                    let available = await isUsernameAvailable(trimmed)
                    if !available {
                        await MainActor.run {
                            completion(.failure(NSError(domain: "AuthVM", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])))
                        }
                        return
                    }
                }

                struct UserPatch: Encodable {
                    let username: String
                    let username_lower: String
                }
                try await supabase
                    .from("users")
                    .update(UserPatch(username: trimmed, username_lower: newLower))
                    .eq("id", value: uid)
                    .execute()

                try await supabase.auth.update(
                    user: UserAttributes(data: ["username": .string(trimmed)])
                )

                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func updateName(_ name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard userId != nil else {
            completion(.failure(NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user"])))
            return
        }
        Task {
            do {
                try await supabase.auth.update(
                    user: UserAttributes(data: ["full_name": .string(name)])
                )
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func updateEmail(_ email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = userId, let uid = UUID(uuidString: userId) else {
            completion(.failure(NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user"])))
            return
        }
        let newEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        AuthService.shared.updateEmail(newEmail) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                Task {
                    do {
                        struct EmailPatch: Encodable { let email: String }
                        try await supabase
                            .from("users")
                            .update(EmailPatch(email: newEmail))
                            .eq("id", value: uid)
                            .execute()
                        await MainActor.run { completion(.success(())) }
                    } catch {
                        await MainActor.run { completion(.failure(error)) }
                    }
                }
            }
        }
    }

    func updatePassword(_ password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await supabase.auth.update(user: UserAttributes(password: password))
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func setPrivateAccount(_ isPrivate: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = userId, let uid = UUID(uuidString: userId) else {
            completion(.failure(NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user"])))
            return
        }
        Task {
            do {
                struct PrivPatch: Encodable { let is_private: Bool }
                try await supabase
                    .from("users")
                    .update(PrivPatch(is_private: isPrivate))
                    .eq("id", value: uid)
                    .execute()

                try await supabase.auth.update(
                    user: UserAttributes(data: ["is_private": .bool(isPrivate)])
                )

                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Email verification (Supabase email OTP / signup)
    func beginEmailVerificationPending(email: String, avatar: UIImage?, userId: UUID? = nil) {
        awaitingEmailVerification = true
        pendingVerificationEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        pendingVerificationUserId = userId
        verificationEmailMaskSource = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        pendingAvatarAfterVerification = avatar
        emailResendAvailableAt = nil
        AuthVerificationRecoveryStore.shared.save(email: email, userId: userId)
    }

    func clearEmailVerificationPending() {
        awaitingEmailVerification = false
        pendingVerificationEmail = nil
        pendingVerificationUserId = nil
        pendingAvatarAfterVerification = nil
        emailResendAvailableAt = nil
        AuthVerificationRecoveryStore.shared.clear()
    }

    /// Verifies the 6-digit code from the signup email, establishes the session, uploads pending avatar, syncs profile.
    func verifySignupEmailOTP(code: String) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6, trimmed.allSatisfy(\.isNumber) else {
            throw NSError(domain: "AuthVM", code: -2, userInfo: [NSLocalizedDescriptionKey: "Enter the 6-digit code from your email."])
        }
        guard let email = pendingVerificationEmail else {
            throw NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing signup email. Go back and sign up again."])
        }
        _ = try await supabase.auth.verifyOTP(email: email, token: trimmed, type: .signup)
        try await finishEmailVerificationAfterSession()
    }

    #if DEBUG || INTERNAL_TESTING
    /// Staging-only: exchange an internal `UT####` code for a real Supabase session.
    var isInternalTestEmailVerificationAvailable: Bool {
        StagingTestEmailVerification.isAvailable && pendingVerificationUserId != nil
    }

    /// Override in unit tests; production DEBUG path uses the live Edge Function client.
    var stagingTestEmailVerifier: StagingTestEmailVerifying = StagingTestEmailVerificationService()

    func verifyInternalTestEmailCode(_ code: String) async throws {
        guard StagingTestEmailVerification.isAvailable else {
            throw StagingTestEmailVerificationError.unavailable
        }
        guard StagingTestEmailVerification.isValidCodeFormat(code) else {
            throw StagingTestEmailVerificationError.invalidFormat
        }
        guard let email = pendingVerificationEmail else {
            throw StagingTestEmailVerificationError.missingPendingUser
        }
        guard let userId = pendingVerificationUserId else {
            throw StagingTestEmailVerificationError.missingPendingUser
        }

        do {
            let exchange = try await stagingTestEmailVerifier.exchange(
                userId: userId,
                email: email,
                code: code
            )
            do {
                _ = try await supabase.auth.verifyOTP(
                    tokenHash: exchange.tokenHash,
                    type: exchange.type
                )
            } catch {
                SpotLogger.log(
                    AuthViewModelLogs.internalTestEmailTokenExchangeFailed,
                    details: ["error": error.localizedDescription]
                )
                throw StagingTestEmailVerificationError.tokenExchangeFailed
            }
            SpotLogger.log(AuthViewModelLogs.internalTestEmailVerificationSucceeded)
            try await finishEmailVerificationAfterSession()
        } catch let error as StagingTestEmailVerificationError {
            SpotLogger.log(
                AuthViewModelLogs.internalTestEmailVerificationDenied,
                details: ["reason": String(describing: error)]
            )
            throw error
        }
    }
    #endif

    private func finishEmailVerificationAfterSession() async throws {
        try await completePendingAvatarUploadIfNeeded()
        clearEmailVerificationPending()
        await SupabaseUserService.shared.syncCurrentUser()
        if let user = try? await supabase.auth.user() {
            await MainActor.run {
                self.isEmailVerified = user.emailConfirmedAt != nil
            }
        }
    }

    private func completePendingAvatarUploadIfNeeded() async throws {
        guard let image = pendingAvatarAfterVerification,
              let data = image.jpegData(compressionQuality: 0.7) else { return }
        let session = try await supabase.auth.session
        let url = try await SupabaseUserService.shared.uploadProfileAvatarJPEG(data, userId: session.user.id)
        struct AvatarPatch: Encodable { let profile_image_url: String }
        try await supabase
            .from("users")
            .update(AvatarPatch(profile_image_url: url))
            .eq("id", value: session.user.id)
            .execute()
    }

    private var pendingVerificationEmail: String?
    private var pendingVerificationUserId: UUID?
    private var pendingAvatarAfterVerification: UIImage?

    func sendVerificationEmail() async throws {
        let email: String?
        if let pending = pendingVerificationEmail {
            email = pending
        } else {
            email = (try? await supabase.auth.session)?.user.email
        }
        guard let email, !email.isEmpty else {
            throw NSError(
                domain: "AuthVM",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "No email available to resend a verification code."]
            )
        }
        do {
            try await supabase.auth.resend(email: email, type: .signup)
            SpotLogger.log(AuthViewModelLogs.verificationEmailSent)
            await MainActor.run { self.emailResendAvailableAt = Date().addingTimeInterval(30) }
        } catch {
            SpotLogger.log(AuthViewModelLogs.sendVerificationEmailFailed, details: ["error": error.localizedDescription])
            throw error
        }
    }

    func canResendVerification() -> Bool {
        guard let t = emailResendAvailableAt else { return true }
        return Date() >= t
    }

    func secondsUntilResend() -> Int {
        guard let t = emailResendAvailableAt else { return 0 }
        return max(0, Int(t.timeIntervalSinceNow.rounded()))
    }

    func checkVerificationStatus() async -> Bool {
        do {
            let user = try await supabase.auth.user()
            let verified = user.emailConfirmedAt != nil
            if verified { SpotLogger.log(AuthViewModelLogs.emailVerified) }
            await MainActor.run { self.isEmailVerified = verified }
            if verified, let uidString = userId, let uid = UUID(uuidString: uidString) {
                struct VerifiedPatch: Encodable { let email_verified: Bool }
                _ = try? await supabase
                    .from("users")
                    .update(VerifiedPatch(email_verified: true))
                    .eq("id", value: uid)
                    .execute()
            }
            return verified
        } catch {
            SpotLogger.log(AuthViewModelLogs.checkVerificationStatusFailed, details: ["error": error.localizedDescription])
            return false
        }
    }

    func verifyBeforeUpdateEmail(_ newEmail: String) async throws {
        do {
            try await supabase.auth.update(user: UserAttributes(email: newEmail))
            SpotLogger.log(AuthViewModelLogs.changeEmailVerifySent)
            await MainActor.run { self.emailResendAvailableAt = Date().addingTimeInterval(30) }
        } catch {
            SpotLogger.log(AuthViewModelLogs.changeEmailError, details: ["error": error.localizedDescription])
            throw error
        }
    }

    var maskedEmail: String {
        let e = verificationEmailMaskSource
        guard let at = e.firstIndex(of: "@") else { return e }
        let name = e[..<at]
        let domain = e[at...]
        let keep = min(2, name.count)
        let head = name.prefix(keep)
        return String(head) + "****" + String(domain)
    }

    // MARK: - Reauthentication
    func reauthenticate(currentPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmed = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Current password is required."])))
            return
        }
        Task {
            do {
                let user = try await supabase.auth.user()
                guard let email = user.email, !email.isEmpty else {
                    throw NSError(domain: "AuthVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing account email for reauthentication."])
                }
                _ = try await supabase.auth.signIn(email: email, password: trimmed)
                await MainActor.run { completion(.success(())) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Username Availability
    func usernameAvailability(_ username: String) async -> UsernameAvailabilityOutcome {
        struct Params: Encodable { let p_username: String }
        do {
            let available: Bool = try await supabase
                .rpc("is_username_available", params: Params(p_username: username))
                .execute()
                .value
            return available ? .available : .taken
        } catch {
            SpotLogger.log(
                AuthViewModelLogs.usernameAvailabilityCheckFailed,
                details: ["error": error.localizedDescription]
            )
            return .unavailable
        }
    }

    func isUsernameAvailable(_ username: String) async -> Bool {
        await usernameAvailability(username) == .available
    }

    // MARK: - Account Deletion

    @Published private(set) var accountDeletionReauthMethod: AccountDeletionReauthMethod = .password

    func refreshAccountDeletionReauthMethod() async {
        #if DEBUG
        if let override = SpotLaunchConfiguration.uiTestAccountDeletionReauth {
            accountDeletionReauthMethod = override
            return
        }
        #endif
        guard let session = try? await supabase.auth.session else { return }
        accountDeletionReauthMethod = AccountDeletionAuthPolicy.preferredReauthMethod(session: session)
    }

    func deleteAccount(password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        runAccountDeletion(completion: completion) { done in
            AuthService.shared.deleteAccount(password: password, completion: done)
        }
    }

    func deleteAccount(
        appleIDToken: String,
        nonce: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        runAccountDeletion(completion: completion) { done in
            AuthService.shared.deleteAccount(
                appleIDToken: appleIDToken,
                nonce: nonce,
                completion: done
            )
        }
    }

    private func runAccountDeletion(
        completion: @escaping (Result<Void, Error>) -> Void,
        _ delete: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void
    ) {
        Task { @MainActor in
            self.accountDeletionInProgress = true
            delete { result in
                Task { @MainActor in
                    defer { self.accountDeletionInProgress = false }
                    switch result {
                    case .success:
                        AuthAccountHintStore.shared.clear()
                        self.clearSignedOutState()
                        await self.teardownSessionCaches()
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Blocking
    func blockUser(userId targetUserId: String) async throws {
        guard let currentUserId = userId,
              let blocker = UUID(uuidString: currentUserId),
              let blocked = UUID(uuidString: targetUserId)
        else { throw NSError(domain: "No current user", code: 0) }
        guard currentUserId != targetUserId else { throw NSError(domain: "Cannot block yourself", code: 0) }

        struct BlockInsert: Encodable {
            let blocker_id: UUID
            let blocked_user_id: UUID
        }
        try await supabase
            .from("user_blocks")
            .insert(BlockInsert(blocker_id: blocker, blocked_user_id: blocked))
            .execute()

        await syncBlockedUsersFromServer()

        SpotLogger.log(AuthViewModelLogs.userBlocked, details: ["targetUserId": targetUserId])
    }

    func unblockUser(userId targetUserId: String) async throws {
        guard let currentUserId = userId,
              let blocker = UUID(uuidString: currentUserId),
              let blocked = UUID(uuidString: targetUserId)
        else { throw NSError(domain: "No current user", code: 0) }

        try await supabase
            .from("user_blocks")
            .delete()
            .eq("blocker_id", value: blocker)
            .eq("blocked_user_id", value: blocked)
            .execute()

        await syncBlockedUsersFromServer()

        SpotLogger.log(AuthViewModelLogs.userUnblocked, details: ["targetUserId": targetUserId])
    }
}

