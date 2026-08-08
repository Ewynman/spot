//
//  PostgresErrorDigestTests.swift
//  SpotTests
//

import Foundation
import Testing
@testable import Spot

struct PostgresErrorDigestTests {

    @Test func detects23505InDescription() {
        let err = NSError(domain: "PostgREST", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "duplicate key value violates unique constraint \"follows_follower_followee_uidx\""
        ])
        #expect(PostgresErrorDigest.isLikelyUniqueViolation(err))
    }

    @Test func detectsDuplicateKeyWording() {
        let err = NSError(domain: "Test", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Duplicate key something"
        ])
        #expect(PostgresErrorDigest.isLikelyUniqueViolation(err))
    }

    @Test func rejectsUnrelatedErrors() {
        let err = NSError(domain: "Test", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "network timed out"
        ])
        #expect(!PostgresErrorDigest.isLikelyUniqueViolation(err))
    }
}
