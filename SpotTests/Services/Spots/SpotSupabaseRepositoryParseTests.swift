//
//  SpotSupabaseRepositoryParseTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  `SpotSupabaseRepository.parseTimestamptz` is the single source of truth
//  for converting Postgres `timestamptz` strings into `Date`. Several
//  decoders (FeedAPI, BookmarksCollectionsService, AuthViewModel proUntil
//  comparison) depend on it, so we cover the format variations Postgres
//  actually emits.
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
}
