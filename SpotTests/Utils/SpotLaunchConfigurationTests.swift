//
//  SpotLaunchConfigurationTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Testing
@testable import Spot

struct SpotLaunchConfigurationTests {

    @Test func uiTestModeIsOffInUnitTestProcessByDefault() {
        #expect(SpotLaunchConfiguration.isUITestMode == false)
    }

    @Test func syntheticUserIdIsStableUuidString() {
        #expect(UUID(uuidString: SpotLaunchConfiguration.uiTestSyntheticUserId) != nil)
    }

    @Test func uiTestAuthBootstrapNilOutsideUITestMode() {
        #expect(SpotLaunchConfiguration.uiTestAuthBootstrap == nil)
    }
}

@Suite(.serialized)
struct UITestSyntheticAuthConfigurationTests {
    @Test func loggedOutClearsSessionFlags() {
        let config = UITestSyntheticAuthConfiguration.make(
            bootstrap: .loggedOut,
            syntheticUserId: "11111111-1111-1111-1111-111111111111",
            isPro: true
        )
        #expect(config == .loggedOut)
        #expect(config.userId == nil)
        #expect(config.isAuthenticated == false)
        #expect(config.isEmailVerified == false)
        #expect(config.isPro == false)
    }

    @Test func loggedInAppliesSyntheticIdentityAndTier() {
        let config = UITestSyntheticAuthConfiguration.make(
            bootstrap: .loggedIn,
            syntheticUserId: "11111111-1111-1111-1111-111111111111",
            isPro: true
        )
        #expect(config.userId == "11111111-1111-1111-1111-111111111111")
        #expect(config.isAuthenticated)
        #expect(config.isEmailVerified)
        #expect(config.isPro)
    }

    @MainActor
    @Test func authViewModelAppliesLoggedInAndLoggedOutSnapshots() {
        let auth = AuthViewModel()
        auth.cancelAuthStateListeningForTests()

        auth.applyUITestSyntheticAuthConfigurationForTests(
            .loggedIn(userId: SpotLaunchConfiguration.uiTestSyntheticUserId, isPro: true),
            accountDeletionReauth: .password
        )
        #expect(auth.isAuthenticated)
        #expect(auth.isEmailVerified)
        #expect(auth.isLoading == false)
        #expect(auth.isPro)
        #expect(auth.userId == SpotLaunchConfiguration.uiTestSyntheticUserId)
        #expect(auth.accountDeletionReauthMethod == .password)

        auth.applyUITestSyntheticAuthConfigurationForTests(.loggedOut)
        #expect(auth.isAuthenticated == false)
        #expect(auth.isEmailVerified == false)
        #expect(auth.isPro == false)
        #expect(auth.userId == nil)
    }

    @MainActor
    @Test func authViewModelInitBootstrapOverrideAppliesSyntheticSession() async {
        AuthViewModel.uiTestBootstrapOverrideForTests = .loggedIn(
            userId: SpotLaunchConfiguration.uiTestSyntheticUserId,
            isPro: true
        )
        AuthViewModel.uiTestAccountDeletionReauthOverrideForTests = .password
        defer {
            AuthViewModel.uiTestBootstrapOverrideForTests = nil
            AuthViewModel.uiTestAccountDeletionReauthOverrideForTests = nil
        }

        let auth = AuthViewModel()
        var becameAuthenticated = false
        for _ in 0..<50 {
            if auth.isAuthenticated {
                becameAuthenticated = true
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(becameAuthenticated)
        #expect(auth.isLoading == false)
        #expect(auth.isEmailVerified)
        #expect(auth.isPro)
        #expect(auth.userId == SpotLaunchConfiguration.uiTestSyntheticUserId)
        #expect(auth.accountDeletionReauthMethod == .password)
        #expect(auth.maskedEmail == VerificationEmailMask.mask(""))

        auth.verificationEmailMaskSource = "eddie@example.com"
        #expect(auth.maskedEmail == "ed****@example.com")
        auth.cancelAuthStateListeningForTests()
    }
}
