//
//  SpotPublishDraftTests.swift
//  SpotTests
//
//  Optimistic feed insert after publish must carry author display fields.
//

import Foundation
import Testing
@testable import Spot

struct SpotPublishDraftTests {

    @Test func draftCarriesAuthorDisplayFieldsForOptimisticFeedInsert() {
        let draft = SpotPublishDraft(
            imageJPEGs: [Data([0xFF, 0xD8, 0xFF])],
            coverMediaDisplayAspectRatio: 1.5,
            vibeTags: ["Scenic View"],
            latitude: 25.0,
            longitude: -77.0,
            placeName: "Ocean Cay",
            userId: "11111111-1111-1111-1111-111111111111",
            username: "Eddie5",
            userProfileImageURL: "https://example.com/a.jpg",
            sourceDraftID: nil
        )
        #expect(draft.username == "Eddie5")
        #expect(draft.userProfileImageURL == "https://example.com/a.jpg")
    }
}
