//
//  ModerationPolicyTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct ModerationPolicyTests {

    @Test func evaluateNilScoresReturnsNotApproved() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: nil)
        #expect(!approved)
        #expect(reason == "missing_scores")
    }

    @Test func evaluateEmptyScoresReturnsApproved() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: [:])
        #expect(approved)
        #expect(reason == nil)
    }

    @Test func evaluateSexualOverThresholdBlocks() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["sexual": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:sexual")
    }

    @Test func evaluateViolenceOverThresholdBlocks() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["violence": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:violence")
    }

    @Test func evaluateHateOverThresholdBlocks() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["hate": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:hate")
    }

    @Test func evaluateSelfHarmOverThresholdBlocks() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["selfharm": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:selfharm")
    }

    @Test func evaluateBelowThresholdApproved() {
        let (approved, _) = ModerationPolicy.evaluate(scores: ["sexual": 2, "violence": 2, "hate": 3])
        #expect(approved)
    }

    @Test func evaluateDoubleValueRounds() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["sexual": 4.2])
        #expect(!approved)
        #expect(reason == "over_threshold:sexual")
    }

    @Test func evaluateStringValueParsed() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["sexual": "4"])
        #expect(!approved)
        #expect(reason == "over_threshold:sexual")
    }

    @Test func evaluateCaseInsensitiveKeys() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["SEXUAL": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:sexual")
    }

    @Test func evaluateAdultAlias() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["adult": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:sexual")
    }

    @Test func evaluateViolentAlias() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["violent": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:violence")
    }

    @Test func evaluateHatespeechAlias() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["hatespeech": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:hate")
    }

    @Test func evaluateSelfInjuryAlias() {
        let (approved, reason) = ModerationPolicy.evaluate(scores: ["selfinjury": 4])
        #expect(!approved)
        #expect(reason == "over_threshold:selfharm")
    }
}
