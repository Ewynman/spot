//
//  HomeFeedRowDecodingTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Testing
@testable import Spot

struct HomeFeedRowDecodingTests {

    private func decode<T: Decodable>(_ json: String, as: T.Type) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - HomeFeedRow

    @Test func decodesFullHomeFeedRow() throws {
        let json = #"""
        {
          "spot_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "vibe_tag_id": "33333333-3333-3333-3333-333333333333",
          "caption": "Hidden gem",
          "latitude": 40.7128,
          "longitude": -74.0060,
          "location_name": "Brooklyn",
          "likes_count": 12,
          "saves_count": 3,
          "created_at": "2026-04-25T12:34:56Z",
          "updated_at": "2026-04-25T12:34:56Z",
          "author_username": "jane",
          "author_profile_image_url": "https://example.com/pfp.jpg",
          "author_is_private": false,
          "vibe_name": "Chill",
          "primary_storage_path": "users/abc/spot.jpg",
          "primary_public_url": null,
          "primary_storage_bucket": "approved_spot_images",
          "source_bucket": "personalized_unseen",
          "rank_position": 5,
          "ranking_score": 0.42,
          "seen_before": false,
          "last_seen_at": null
        }
        """#
        let row = try decode(json, as: HomeFeedRow.self)
        #expect(row.spotId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(row.userId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(row.vibeTagId == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(row.caption == "Hidden gem")
        #expect(row.latitude == 40.7128)
        #expect(row.longitude == -74.0060)
        #expect(row.locationName == "Brooklyn")
        #expect(row.likesCount == 12)
        #expect(row.savesCount == 3)
        #expect(row.authorUsername == "jane")
        #expect(row.authorProfileImageUrl == "https://example.com/pfp.jpg")
        #expect(row.authorIsPrivate == false)
        #expect(row.vibeName == "Chill")
        #expect(row.primaryStoragePath == "users/abc/spot.jpg")
        #expect(row.primaryPublicUrl == nil)
        #expect(row.primaryStorageBucket == "approved_spot_images")
        #expect(row.sourceBucket == "personalized_unseen")
        #expect(row.rankPosition == 5)
        #expect(row.rankingScore == 0.42)
        #expect(row.seenBefore == false)
        #expect(row.lastSeenAt == nil)
    }

    @Test func decodesRowWithMissingOptionals() throws {
        let json = #"""
        {
          "spot_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "source_bucket": "following_new",
          "rank_position": 0,
          "ranking_score": 1000.5,
          "seen_before": false
        }
        """#
        let row = try decode(json, as: HomeFeedRow.self)
        #expect(row.caption == nil)
        #expect(row.likesCount == nil)
        #expect(row.savesCount == nil)
        #expect(row.lastSeenAt == nil)
        #expect(row.primaryStorageBucket == nil)
        #expect(row.sourceBucket == "following_new")
    }

    @Test func decodesRowWithMediaDisplayAspectRatio() throws {
        let json = #"""
        {
          "spot_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "source_bucket": "personalized_unseen",
          "rank_position": 0,
          "ranking_score": 1.0,
          "seen_before": false,
          "media_display_aspect_ratio": 1.7777
        }
        """#
        let row = try decode(json, as: HomeFeedRow.self)
        #expect(row.mediaDisplayAspectRatio != nil)
        #expect(abs((row.mediaDisplayAspectRatio ?? 0) - 1.7777) < 0.0001)
    }

    @Test func decodesRowWithSeenFallbackBucket() throws {
        let json = #"""
        {
          "spot_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "source_bucket": "seen_fallback",
          "rank_position": 3,
          "ranking_score": 0.18,
          "seen_before": true,
          "last_seen_at": "2026-04-20T08:00:00Z"
        }
        """#
        let row = try decode(json, as: HomeFeedRow.self)
        #expect(row.sourceBucket == "seen_fallback")
        #expect(row.seenBefore == true)
        #expect(row.lastSeenAt != nil)
    }

    // MARK: - HomeFeedStatus

    @Test func decodesAllStatusEnumValues() throws {
        for status in ["has_unseen", "caught_up", "no_eligible_spots", "no_spots_global"] {
            let json = """
            {
              "total_spots": 1000,
              "eligible_spots": 800,
              "unseen_eligible_spots": 50,
              "seen_eligible_spots": 750,
              "status": "\(status)"
            }
            """
            let parsed = try decode(json, as: HomeFeedStatus.self)
            #expect(parsed.status == status)
            #expect(parsed.totalSpots == 1000)
            #expect(parsed.eligibleSpots == 800)
            #expect(parsed.unseenEligibleSpots == 50)
            #expect(parsed.seenEligibleSpots == 750)
        }
    }

    // MARK: - MapSpotRow

    @Test func decodesMapSpotRow() throws {
        let json = #"""
        {
          "spot_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "vibe_tag_id": null,
          "caption": "Map spot",
          "latitude": 40.0,
          "longitude": -74.0,
          "location_name": "NYC",
          "created_at": "2026-04-25T00:00:00Z",
          "author_username": "explorer",
          "author_profile_image_url": null,
          "vibe_name": null,
          "primary_storage_path": "spots/x.jpg",
          "primary_public_url": null,
          "primary_storage_bucket": "spots",
          "distance_meters": 1234.5
        }
        """#
        let row = try decode(json, as: MapSpotRow.self)
        #expect(row.locationName == "NYC")
        #expect(row.distanceMeters == 1234.5)
        #expect(row.primaryStoragePath == "spots/x.jpg")
        #expect(row.primaryStorageBucket == "spots")
        #expect(row.vibeTagId == nil)
        #expect(row.vibeName == nil)
    }

    @Test func resolvedPrimaryStorageBucketFallsBackToLegacySpots() {
        #expect(FeedAPI.resolvedPrimaryStorageBucket(nil) == "spots")
        #expect(FeedAPI.resolvedPrimaryStorageBucket("") == "spots")
        #expect(FeedAPI.resolvedPrimaryStorageBucket("  ") == "spots")
        #expect(FeedAPI.resolvedPrimaryStorageBucket("approved_spot_images") == "approved_spot_images")
    }
}
