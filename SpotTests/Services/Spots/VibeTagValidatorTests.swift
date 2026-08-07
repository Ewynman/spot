//
//  VibeTagValidatorTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct VibeTagValidatorTests {

    @Test func validateTooShort() {
        let validator = VibeTagValidator()
        if case .tooShort = validator.validate("a") { } else { Issue.record("Expected tooShort") }
    }

    @Test func validateTooLong() {
        let validator = VibeTagValidator()
        let long = String(repeating: "x", count: 31)
        if case .tooLong = validator.validate(long) { } else { Issue.record("Expected tooLong") }
    }

    @Test func validateOkValidTag() {
        let validator = VibeTagValidator()
        if case .ok(let s) = validator.validate("Chill Spot") {
            #expect(s == "Chill Spot")
        } else { Issue.record("Expected ok") }
    }

    @Test func validateTrimsWhitespace() {
        let validator = VibeTagValidator()
        if case .ok(let s) = validator.validate("  Hidden Gem  ") {
            #expect(s == "Hidden Gem")
        } else { Issue.record("Expected ok") }
    }

    @Test func validateBlockedExact() {
        let validator = VibeTagValidator()
        if case .blocked = validator.validate("fuck") { } else { Issue.record("Expected blocked") }
    }

    @Test func validateBlockedContains() {
        let validator = VibeTagValidator()
        if case .blocked = validator.validate("xxxfuckxxx") { } else { Issue.record("Expected blocked") }
    }

    @Test func validateOkAtMinLength() {
        let validator = VibeTagValidator()
        if case .ok = validator.validate("abc") { } else { Issue.record("Expected ok at min") }
    }

    @Test func validateOkAtMaxLength() {
        let validator = VibeTagValidator()
        let s = String(repeating: "x", count: 20)
        if case .ok = validator.validate(s) { } else { Issue.record("Expected ok at max") }
    }
}
