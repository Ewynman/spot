//
//  PlaceNameValidatorTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct PlaceNameValidatorTests {

    @Test func validateTooShort() {
        let validator = PlaceNameValidator()
        if case .tooShort = validator.validate("a") { } else { Issue.record("Expected tooShort") }
    }

    @Test func validateTooLong() {
        let validator = PlaceNameValidator()
        let long = String(repeating: "x", count: 61)
        if case .tooLong = validator.validate(long) { } else { Issue.record("Expected tooLong") }
    }

    @Test func validateOk() {
        let validator = PlaceNameValidator()
        if case .ok(let s) = validator.validate("Central Park") {
            #expect(!s.isEmpty)
        } else { Issue.record("Expected ok") }
    }

    @Test func validateBlockedExact() {
        let validator = PlaceNameValidator()
        if case .blocked = validator.validate("fuck") { } else { Issue.record("Expected blocked") }
    }

    @Test func validateBlockedContains() {
        let validator = PlaceNameValidator()
        if case .blocked = validator.validate("My fuck place") { } else { Issue.record("Expected blocked") }
    }

    @Test func validateOkAtMinLength() {
        let validator = PlaceNameValidator()
        if case .ok = validator.validate("abc") { } else { Issue.record("Expected ok") }
    }

    @Test func validateOkAtMaxLength() {
        let validator = PlaceNameValidator()
        let s = String(repeating: "a", count: 20)
        if case .ok = validator.validate(s) { } else { Issue.record("Expected ok at max") }
    }
}
