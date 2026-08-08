//
//  FeedEventTypeTests.swift
//  SpotTests
//
//  Locks in the wire-format contract between iOS `FeedEventType` raw values
//  and the server-side `public.feed_event_weight_v1` weighting table. If the
//  iOS rawValue and the server weight key drift, events silently log with
//  weight 0 and personalization breaks — these tests catch that at CI time.
//

import Testing
@testable import Spot

struct FeedEventTypeTests {

    // MARK: - Server weight contract

    @Test func impressionRawValue() {
        #expect(FeedEventType.impression.rawValue == "impression")
    }

    @Test func visible2sRawValue() {
        #expect(FeedEventType.visible2s.rawValue == "visible_2s")
    }

    @Test func longDwellRawValue() {
        #expect(FeedEventType.longDwell.rawValue == "long_dwell")
    }

    @Test func detailOpenRawValue() {
        #expect(FeedEventType.detailOpen.rawValue == "detail_open")
    }

    @Test func quickSkipRawValue() {
        #expect(FeedEventType.quickSkip.rawValue == "quick_skip")
    }

    @Test func likeRawValue() {
        #expect(FeedEventType.like.rawValue == "like")
    }

    @Test func unlikeRawValue() {
        #expect(FeedEventType.unlike.rawValue == "unlike")
    }

    @Test func saveRawValue() {
        #expect(FeedEventType.save.rawValue == "save")
    }

    @Test func unsaveRawValue() {
        #expect(FeedEventType.unsave.rawValue == "unsave")
    }

    @Test func shareRawValue() {
        #expect(FeedEventType.share.rawValue == "share")
    }

    @Test func profileTapRawValue() {
        #expect(FeedEventType.profileTap.rawValue == "profile_tap")
    }

    @Test func vibeTapRawValue() {
        #expect(FeedEventType.vibeTap.rawValue == "vibe_tap")
    }

    @Test func mapPinTapRawValue() {
        #expect(FeedEventType.mapPinTap.rawValue == "map_pin_tap")
    }

    @Test func hideRawValue() {
        #expect(FeedEventType.hide.rawValue == "hide")
    }

    @Test func reportAuthorRawValue() {
        // Server weight table keys this as "report" — the iOS case is named
        // `reportAuthor` for clarity but the wire value must stay "report".
        #expect(FeedEventType.reportAuthor.rawValue == "report")
    }

    @Test func blockAuthorRawValue() {
        #expect(FeedEventType.blockAuthor.rawValue == "block_author")
    }

    @Test func followAuthorRawValue() {
        #expect(FeedEventType.followAuthor.rawValue == "follow_author")
    }

    @Test func unfollowAuthorRawValue() {
        #expect(FeedEventType.unfollowAuthor.rawValue == "unfollow_author")
    }

    // MARK: - Round-trip

    @Test func roundTripFromRawValue() {
        let allCases: [FeedEventType] = [
            .impression, .visible2s, .longDwell, .detailOpen, .quickSkip,
            .like, .unlike, .save, .unsave, .share,
            .profileTap, .vibeTap, .mapPinTap,
            .hide, .reportAuthor, .blockAuthor, .followAuthor, .unfollowAuthor
        ]
        for c in allCases {
            #expect(FeedEventType(rawValue: c.rawValue) == c)
        }
    }
}
