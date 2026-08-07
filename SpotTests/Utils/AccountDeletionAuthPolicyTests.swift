//
//  AccountDeletionAuthPolicyTests.swift
//  SpotTests
//

import Auth
import Foundation
import Supabase
import Testing
@testable import Spot

struct AccountDeletionAuthPolicyTests {

    @Test func appleOnlyAccountUsesSignInWithAppleReauth() {
        let session = makeSession(providers: ["apple"])
        #expect(AccountDeletionAuthPolicy.preferredReauthMethod(session: session) == .signInWithApple)
    }

    @Test func emailAccountUsesPasswordReauth() {
        let session = makeSession(providers: ["email"])
        #expect(AccountDeletionAuthPolicy.preferredReauthMethod(session: session) == .password)
    }

    @Test func appleAndEmailAccountUsesPasswordReauth() {
        let session = makeSession(providers: ["apple", "email"])
        #expect(AccountDeletionAuthPolicy.preferredReauthMethod(session: session) == .password)
    }

    private func makeSession(providers: [String]) -> Session {
        let uid = UUID()
        let identities = providers.map { provider in
            UserIdentity(
                id: "id-\(provider)",
                identityId: UUID(),
                userId: uid,
                identityData: [:],
                provider: provider,
                createdAt: nil,
                lastSignInAt: nil,
                updatedAt: nil
            )
        }
        let now = Date()
        let user = User(
            id: uid,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            createdAt: now,
            updatedAt: now,
            identities: identities
        )
        return Session(
            accessToken: "x",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: now.timeIntervalSince1970 + 3600,
            refreshToken: "",
            user: user
        )
    }
}
