//
//  SpotSupabaseRepositoryParseTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 4/27/26.
//

import Foundation
import Testing
@testable import Spot

struct SpotSupabaseRepositoryParseTests {


    @Test func parsesIso8601WithFractionalSeconds() {
        let raw = "2026-04-27T16:30:00.123Z"
        let date = SpotSupabaseRepository.parseTimestamptz(raw)
        #expect(date != nil)
    }

    @Test func parsesPlainIso8601WithoutFractional() {
        let raw = "2026-04-27T16:30:00Z"
        let date = SpotSupabaseRepository.parseTimestamptz(raw)
        #expect(date != nil)
    }

    @Test func parsesIso8601WithExplicitOffset() {
        let raw = "2026-04-27T12:30:00-04:00"
        let date = SpotSupabaseRepository.parseTimestamptz(raw)
        #expect(date != nil)
    }

    @Test func returnsNilForNilOrEmpty() {
        #expect(SpotSupabaseRepository.parseTimestamptz(nil) == nil)
        #expect(SpotSupabaseRepository.parseTimestamptz("") == nil)
    }

    @Test func returnsNilForGarbageString() {
        #expect(SpotSupabaseRepository.parseTimestamptz("not-a-date") == nil)
        #expect(SpotSupabaseRepository.parseTimestamptz("2026-13-99") == nil)
    }

    @Test func roundTripPreservesUtcInstant() {
        let raw = "2026-01-01T00:00:00Z"
        let parsed = SpotSupabaseRepository.parseTimestamptz(raw)
        #expect(parsed != nil)
        if let parsed {
            // 2026-01-01 UTC == 1767225600 seconds since 1970.
            #expect(Int(parsed.timeIntervalSince1970) == 1_767_225_600)
        }
    }

    @Test func postgresILikeEscapeLeavesPlainText() {
        #expect(SpotSupabaseRepository.postgresILikeEscaped("new york") == "new york")
    }

    @Test func postgresILikeEscapeEscapesWildcardsAndBackslash() {
        #expect(SpotSupabaseRepository.postgresILikeEscaped("a%b_c\\d") == "a\\%b\\_c\\\\d")
    }

    @Test func detectsAbsoluteStoredURLs() {
        #expect(SpotSupabaseRepository.isStoredAbsoluteURLForTests("https://cdn.example/p.jpg"))
        #expect(SpotSupabaseRepository.isStoredAbsoluteURLForTests("http://cdn.example/p.jpg"))
        #expect(!SpotSupabaseRepository.isStoredAbsoluteURLForTests("users/abc/photo.jpg"))
    }

    @Test func parseModerateImageJSONRequiresApprovedBoolean() throws {
        let approved = try #require(#"{"approved":true,"reason":"ok"}"#.data(using: .utf8))
        let parsedApproved = SpotSupabaseRepository.parseModerateImageJSON(approved)
        #expect(parsedApproved.approved)
        #expect(parsedApproved.reason == "ok")

        let placeholder = try #require(#"{"ok":true}"#.data(using: .utf8))
        let parsedPlaceholder = SpotSupabaseRepository.parseModerateImageJSON(placeholder)
        #expect(!parsedPlaceholder.approved)

        let invalid = try #require("not-json".data(using: .utf8))
        let parsedInvalid = SpotSupabaseRepository.parseModerateImageJSON(invalid)
        #expect(!parsedInvalid.approved)
        #expect(parsedInvalid.reason == "moderation_unavailable")
    }
}
