//
//  StringNormalizerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct StringNormalizerTests {

    @Test func normalizedLowercases() {
        #expect(StringNormalizer.normalized("HELLO") == "helo")
    }

    @Test func normalizedRemovesDiacritics() {
        let result = StringNormalizer.normalized("café")
        #expect(result.contains("e"))
        #expect(!result.contains("é"))
    }

    @Test func normalizedMapsLeetChars() {
        #expect(StringNormalizer.normalized("h3ll0") == "helo")
        #expect(StringNormalizer.normalized("p@ss") == "pas")
        #expect(StringNormalizer.normalized("te$t") == "test")
    }

    @Test func normalizedRemovesNonAlphanumeric() {
        #expect(StringNormalizer.normalized("hello world") == "heloworld")
        #expect(StringNormalizer.normalized("a_b_c") == "abc")
    }

    @Test func normalizedCollapsesRepeats() {
        #expect(StringNormalizer.normalized("heeeeello") == "helo")
    }

    @Test func normalizedEmptyString() {
        #expect(StringNormalizer.normalized("") == "")
    }

    @Test func normalizedWhitespaceOnly() {
        #expect(StringNormalizer.normalized("   ") == "")
    }
}
