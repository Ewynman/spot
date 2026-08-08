//
//  UsernameValidatorTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct UsernameValidatorTests {

    @Test func validateTooShort() {
        let validator = UsernameValidator()
        if case .tooShort = validator.validate("ab") { } else { Issue.record("Expected tooShort") }
    }

    @Test func validateTooLong() {
        let validator = UsernameValidator()
        let long = String(repeating: "a", count: 21)
        if case .tooLong = validator.validate(long) { } else { Issue.record("Expected tooLong") }
    }

    @Test func validateOk() {
        let validator = UsernameValidator()
        if case .ok = validator.validate("validuser123") { } else { Issue.record("Expected ok") }
    }

    @Test func validateReserved() {
        let validator = UsernameValidator()
        if case .reserved = validator.validate("admin") { } else { Issue.record("Expected reserved") }
    }

    @Test func validateInvalidCharsLeadingDot() {
        let validator = UsernameValidator()
        if case .invalidChars = validator.validate(".user") { } else { Issue.record("Expected invalidChars") }
    }

    @Test func validateInvalidCharsTrailingDash() {
        let validator = UsernameValidator()
        if case .invalidChars = validator.validate("user-") { } else { Issue.record("Expected invalidChars") }
    }

    @Test func validateInvalidCharsConsecutive() {
        let validator = UsernameValidator()
        if case .invalidChars = validator.validate("user__name") { } else { Issue.record("Expected invalidChars") }
    }

    @Test func validateInvalidCharsMixedConsecutiveSeparators() {
        let validator = UsernameValidator()
        if case .invalidChars = validator.validate("user_-name") { } else { Issue.record("Expected invalidChars") }
    }

    @Test func validateInvalidCharsDisallowedChars() {
        let validator = UsernameValidator()
        if case .invalidChars = validator.validate("user name") { } else { Issue.record("Expected invalidChars") }
    }

    @Test func validateBlockedExact() {
        let validator = UsernameValidator()
        if case .blocked = validator.validate("fuck") { } else { Issue.record("Expected blocked") }
    }

    @Test func validateBlockedReverseExact() {
        let validator = UsernameValidator()
        if case .blocked(let term) = validator.validate("kcuf") {
            #expect(term == "reverse_exact")
        } else { Issue.record("Expected blocked reverse_exact") }
    }

    @Test func validateOkAtMinLength() {
        let validator = UsernameValidator()
        if case .ok = validator.validate("abc") { } else { Issue.record("Expected ok") }
    }

    @Test func normalizedRemovesSeparators() {
        let validator = UsernameValidator()
        if case .ok = validator.validate("valid.user-name") { } else { Issue.record("Expected ok with separators") }
    }
}
