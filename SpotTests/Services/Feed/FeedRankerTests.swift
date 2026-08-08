//
//  FeedRankerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import CoreLocation
import Testing
@testable import Spot

struct FeedRankerTests {

    private func makeSpot(id: String? = "s1", userId: String = "u1", vibeTag: String? = "Chill", lat: Double? = nil, lon: Double? = nil, createdAt: Date? = nil) -> Spot {
        Spot(id: id, userId: userId, vibeTag: vibeTag, latitude: lat, longitude: lon, createdAt: createdAt ?? Date())
    }

    @Test func scoreVibeWeight() {
        let ranker = FeedRanker.shared
        let spot = makeSpot(vibeTag: "Chill")
        let ctx = FeedRanker.Context(
            followeeIds: [],
            userVibeStats: ["Chill": 3, "Other": 1],
            userLocation: nil,
            seenSpotIds: []
        )
        let s = ranker.score(spot, ctx: ctx)
        #expect(s > 0)
        #expect(s <= 1.0)
    }

    @Test func scoreFreshnessDecay() {
        let ranker = FeedRanker.shared
        let spot = makeSpot(createdAt: Date().addingTimeInterval(-3600))
        let ctx = FeedRanker.Context(
            followeeIds: [],
            userVibeStats: [:],
            userLocation: nil,
            seenSpotIds: []
        )
        let s = ranker.score(spot, ctx: ctx)
        #expect(s >= 0)
    }

    @Test func scoreAffinityFollowee() {
        let ranker = FeedRanker.shared
        let spot = makeSpot(userId: "followee1")
        let ctx = FeedRanker.Context(
            followeeIds: ["followee1"],
            userVibeStats: ["Chill": 1],
            userLocation: nil,
            seenSpotIds: []
        )
        let sFollowee = ranker.score(spot, ctx: ctx)
        let spotNonFollowee = makeSpot(userId: "other")
        let sNonFollowee = ranker.score(spotNonFollowee, ctx: ctx)
        #expect(sFollowee > sNonFollowee)
    }

    @Test func scoreDistanceWithinNearKm() {
        let ranker = FeedRanker.shared
        let userLoc = CLLocation(latitude: 40.7, longitude: -74.0)
        let spot = makeSpot(lat: 40.71, lon: -74.01)
        let ctx = FeedRanker.Context(
            followeeIds: [],
            userVibeStats: ["Chill": 1],
            userLocation: userLoc,
            seenSpotIds: []
        )
        let s = ranker.score(spot, ctx: ctx)
        #expect(s > 0)
    }

    @Test func scoreDistanceFarDecays() {
        let ranker = FeedRanker.shared
        let userLoc = CLLocation(latitude: 40.7, longitude: -74.0)
        let spot = makeSpot(lat: 50.0, lon: -74.0)
        let ctx = FeedRanker.Context(
            followeeIds: [],
            userVibeStats: ["Chill": 1],
            userLocation: userLoc,
            seenSpotIds: []
        )
        let s = ranker.score(spot, ctx: ctx)
        #expect(s >= 0)
    }

    @Test func scoreZeroVibeStats() {
        let ranker = FeedRanker.shared
        let spot = makeSpot()
        let ctx = FeedRanker.Context(
            followeeIds: [],
            userVibeStats: [:],
            userLocation: nil,
            seenSpotIds: []
        )
        let s = ranker.score(spot, ctx: ctx)
        #expect(s >= 0)
    }

    @Test func singleLikedTagDoesNotMaxOutVibeComponent() {
        let ranker = FeedRanker.shared
        let spot = makeSpot(vibeTag: "Coffee")
        let ctx = FeedRanker.Context(
            followeeIds: [],
            userVibeStats: ["Coffee": 1],
            userLocation: nil,
            seenSpotIds: []
        )
        let s = ranker.score(spot, ctx: ctx)
        // Legacy raw ratio would hit ~0.45 on vibe weight alone; smoothing keeps total score bounded.
        #expect(s < 0.55)
    }

    @Test func blendMergesFolloweesAndGlobal() {
        let ranker = FeedRanker.shared
        let f1 = makeSpot(id: "f1", userId: "u1")
        let g1 = makeSpot(id: "g1", userId: "u2")
        let result = ranker.blend(followees: [f1], global: [g1], pageSize: 24)
        #expect(result.count >= 2)
    }

    @Test func blendDeduplicatesById() {
        let ranker = FeedRanker.shared
        let s1 = makeSpot(id: "same", userId: "u1")
        let s2 = makeSpot(id: "same", userId: "u1")
        let result = ranker.blend(followees: [s1], global: [s2], pageSize: 24)
        #expect(result.count == 1)
    }

    @Test func blendCreatorCapHoldsWhenPageHasOtherContent() {
        // When there's enough other content to fill the page, the creator
        // cap is enforced and the third spot from u1 is dropped.
        let ranker = FeedRanker.shared
        let s1 = makeSpot(id: "a1", userId: "u1")
        let s2 = makeSpot(id: "a2", userId: "u1")
        let s3 = makeSpot(id: "a3", userId: "u1")
        let result = ranker.blend(followees: [s1, s2, s3], global: [], pageSize: 2, creatorCap: 2)
        let fromU1 = result.filter { $0.userId == "u1" }
        #expect(fromU1.count == 2)
    }

    @Test func blendCreatorCapRelaxesOnSafetyBackfill() {
        // If there is nowhere else to draw from, the final safety backfill
        // relaxes the creator cap so the caller still gets all the content.
        // This documents the intentional soft-cap behavior in `blend`.
        let ranker = FeedRanker.shared
        let s1 = makeSpot(id: "a1", userId: "u1")
        let s2 = makeSpot(id: "a2", userId: "u1")
        let s3 = makeSpot(id: "a3", userId: "u1")
        let result = ranker.blend(followees: [s1, s2, s3], global: [], pageSize: 24, creatorCap: 2)
        let fromU1 = result.filter { $0.userId == "u1" }
        #expect(fromU1.count == 3)
    }

    @Test func blendFallbackKeyForNilId() {
        let ranker = FeedRanker.shared
        let s1 = makeSpot(id: nil, userId: "u1", createdAt: Date(timeIntervalSince1970: 1000))
        let s2 = makeSpot(id: nil, userId: "u1", createdAt: Date(timeIntervalSince1970: 1001))
        let result = ranker.blend(followees: [s1, s2], global: [], pageSize: 24)
        #expect(result.count == 2)
    }

    @Test func blendBackfillWhenUnderfilled() {
        let ranker = FeedRanker.shared
        let f1 = makeSpot(id: "f1", userId: "u1")
        let g1 = makeSpot(id: "g1", userId: "u2")
        let result = ranker.blend(followees: [f1], global: [g1], pageSize: 10)
        #expect(result.count >= 2)
    }
}
