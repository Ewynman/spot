//
//  PasswordValidatorTests.swift
//  SpotTests
//

import Testing
@testable import Spot

struct PasswordValidatorTests {
    @Test func acceptsValidPassword() {
        if case .ok = PasswordValidator.validate("GoodP4ss!") {} else { Issue.record("Expected ok") }
    }

    @Test func rejectsTooShort() {
        if case .failure = PasswordValidator.validate("Aa1!x") {} else { Issue.record("Expected failure") }
    }

    @Test func rejectsMissingUppercase() {
        if case .failure = PasswordValidator.validate("weakp4ss!") {} else { Issue.record("Expected failure") }
    }

    @Test func rejectsMissingSymbol() {
        if case .failure = PasswordValidator.validate("Weakpass4") {} else { Issue.record("Expected failure") }
    }
}
