//
//  AuthProfileSetupGateTests.swift
//  SpotTests
//

import Auth
import Foundation
import Supabase
import Testing
@testable import Spot

struct AuthProfileSetupGateTests {

    @Test func appleIdentityEnablesPostAuthProfileGate() {
        let uid = UUID()
        let identity = UserIdentity(
            id: "id-1",
            identityId: UUID(),
            userId: uid,
            identityData: [:],
            provider: "apple",
            createdAt: nil,
            lastSignInAt: nil,
            updatedAt: nil
        )
        let now = Date()
        let user = User(
            id: uid,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            createdAt: now,
            updatedAt: now,
            identities: [identity]
        )
        let session = Session(
            accessToken: "x",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "",
            user: user
        )
        #expect(AuthProfileSetupGate.shouldShowUsernamePhotoPostAuthSetup(session: session))
    }

    @Test func emailIdentityDoesNotEnableGate() {
        let uid = UUID()
        let identity = UserIdentity(
            id: "id-1",
            identityId: UUID(),
            userId: uid,
            identityData: [:],
            provider: "email",
            createdAt: nil,
            lastSignInAt: nil,
            updatedAt: nil
        )
        let now = Date()
        let user = User(
            id: uid,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            createdAt: now,
            updatedAt: now,
            identities: [identity]
        )
        let session = Session(
            accessToken: "x",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "",
            user: user
        )
        #expect(!AuthProfileSetupGate.shouldShowUsernamePhotoPostAuthSetup(session: session))
    }

    @Test func appMetadataProviderAppleEnablesGate() {
        let uid = UUID()
        let now = Date()
        let user = User(
            id: uid,
            appMetadata: ["provider": .string("apple")],
            userMetadata: [:],
            aud: "authenticated",
            createdAt: now,
            updatedAt: now,
            identities: nil
        )
        let session = Session(
            accessToken: "x",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "",
            user: user
        )
        #expect(AuthProfileSetupGate.shouldShowUsernamePhotoPostAuthSetup(session: session))
    }
}
