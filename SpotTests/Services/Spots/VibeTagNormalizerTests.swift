//
//  VibeTagNormalizerTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Testing
@testable import Spot

struct VibeTagNormalizerTests {

    @Test func stringNormalizerCollapsesHomoglyphs() {
        let norm = StringNormalizer.normalized("B3ach!!")
        #expect(norm.contains("beach"))
    }

    @Test func vibeValidatorTrimsBeforeNormalizationGate() {
        let validator = VibeTagValidator()
        if case .ok(let cleaned) = validator.validate("  Cozy  ") {
            #expect(cleaned == "Cozy")
        } else {
            Issue.record("Expected trimmed ok")
        }
    }
}
