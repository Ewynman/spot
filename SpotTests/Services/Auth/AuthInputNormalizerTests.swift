//
//  AuthInputNormalizerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Tests the pure auth-input helpers AuthService relies on for sign-up,
//  sign-in, password reset, and username/email resolution.
//

import Foundation
import Testing
@testable import Spot

struct AuthInputNormalizerTests {

    @Test func emailIsLowercasedAndTrimmed() throws {
        #expect(try AuthInputNormalizer.normalizeEmail("  Foo@Example.COM  ") == "foo@example.com")
    }

    @Test func emailWithoutWhitespaceJustLowercases() throws {
        #expect(try AuthInputNormalizer.normalizeEmail("BAR@example.com") == "bar@example.com")
    }

    @Test func emptyEmailThrows() {
        #expect(throws: (any Error).self) {
            try AuthInputNormalizer.normalizeEmail("")
        }
        #expect(throws: (any Error).self) {
            try AuthInputNormalizer.normalizeEmail("   \n\t ")
        }
    }

    @Test func invalidEmailWithInternalWhitespaceThrows() {
        // Supabase will reject these, and the normalizer now validates format.
        #expect(throws: (any Error).self) {
            try AuthInputNormalizer.normalizeEmail("Foo Bar@example.com")
        }
    }

    @Test func usernameIsTrimmedNotLowercased() throws {
        #expect(try AuthInputNormalizer.normalizeUsername("  Edward  ") == "Edward")
    }

    @Test func usernameLowerIsTrimmedAndLowercased() throws {
        #expect(try AuthInputNormalizer.normalizeUsernameLower("  Edward_42 ") == "edward_42")
    }

    @Test func whitespaceOnlyUsernameThrows() {
        #expect(throws: (any Error).self) {
            try AuthInputNormalizer.normalizeUsername("   ")
        }
        #expect(throws: (any Error).self) {
            try AuthInputNormalizer.normalizeUsernameLower("\n\t")
        }
    }
}

struct AuthErrorClassifierTests {

    @Test func detectsAlreadyKeyword() {
        #expect(AuthErrorClassifier.isEmailInUse("User already exists") == true)
    }

    @Test func detectsExistsKeyword() {
        #expect(AuthErrorClassifier.isEmailInUse("This email exists in our system") == true)
    }

    @Test func detectsRegisteredKeyword() {
        #expect(AuthErrorClassifier.isEmailInUse("Email address has been registered") == true)
    }

    @Test func ignoresUnrelatedMessages() {
        #expect(AuthErrorClassifier.isEmailInUse("Network error") == false)
        #expect(AuthErrorClassifier.isEmailInUse("Invalid password") == false)
    }

    @Test func isCaseInsensitive() {
        #expect(AuthErrorClassifier.isEmailInUse("ALREADY IN USE") == true)
        #expect(AuthErrorClassifier.isEmailInUse("eMaIl ExIsTs") == true)
    }

    @Test func errorOverloadDelegatesToMessage() {
        let err = NSError(
            domain: "Test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Already registered"]
        )
        #expect(AuthErrorClassifier.isEmailInUse(error: err) == true)
    }

    @Test func emptyMessageIsNotEmailInUse() {
        #expect(AuthErrorClassifier.isEmailInUse("") == false)
    }

    // MARK: - Existing-account sign-up detection

    @Test func existingAccountWhenNoSessionAndNoIdentities() {
        // Supabase repeated-signup obfuscation: HTTP 200, no session, empty identities.
        #expect(AuthErrorClassifier.isExistingAccountSignup(hasSession: false, identityCount: 0) == true)
    }

    @Test func newSignupWithIdentityIsNotExistingAccount() {
        // A genuine new email signup (confirm-email on) returns one identity, no session.
        #expect(AuthErrorClassifier.isExistingAccountSignup(hasSession: false, identityCount: 1) == false)
    }

    @Test func autoConfirmedSessionIsNotExistingAccount() {
        // Auto-confirm flows return a session; never treat as existing account.
        #expect(AuthErrorClassifier.isExistingAccountSignup(hasSession: true, identityCount: 0) == false)
        #expect(AuthErrorClassifier.isExistingAccountSignup(hasSession: true, identityCount: 1) == false)
    }
}

struct EmailInUseTypeTests {

    @Test func passwordAccountMessageMentionsSignIn() {
        let type = EmailInUseType.passwordAccount
        #expect(type.message.lowercased().contains("sign in"))
        #expect(type.suggestedActions.contains("Sign In"))
        #expect(type.suggestedActions.contains("Forgot Password"))
    }

    @Test func federatedAppleMessageMentionsApple() {
        let type = EmailInUseType.federatedAccount("apple.com")
        #expect(type.message.contains("Apple"))
        #expect(type.suggestedActions.contains("Continue with Apple"))
    }

    @Test func federatedGoogleMessageMentionsGoogle() {
        let type = EmailInUseType.federatedAccount("google.com")
        #expect(type.message.contains("Google"))
        #expect(type.suggestedActions.contains("Continue with Google"))
    }

    @Test func inconsistentStateProvidesTryAgain() {
        let type = EmailInUseType.inconsistentState
        #expect(type.suggestedActions.contains("Try Again"))
        #expect(!type.message.isEmpty)
    }
}
