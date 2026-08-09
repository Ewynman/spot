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
        #expect(draft.vibeDisplayMode == .rotating)
    }

    @Test func draftCanCarryPhotoSyncedMode() {
        let draft = SpotPublishDraft(
            imageJPEGs: [Data([0xFF, 0xD8, 0xFF]), Data([0xFF, 0xD8, 0xFF])],
            coverMediaDisplayAspectRatio: 1.0,
            vibeTags: ["A", "B"],
            latitude: 1,
            longitude: 2,
            placeName: "Place",
            userId: "11111111-1111-1111-1111-111111111111",
            username: nil,
            userProfileImageURL: nil,
            sourceDraftID: nil,
            vibeDisplayMode: .photoSynced
        )
        #expect(draft.vibeDisplayMode == .photoSynced)
    }

    @Test func makePostedSpotCarriesPhotoSyncedFields() {
        let draft = SpotPublishDraft(
            imageJPEGs: [Data([0xFF, 0xD8, 0xFF]), Data([0xFF, 0xD8, 0xFF])],
            coverMediaDisplayAspectRatio: 1.25,
            vibeTags: ["A", "B"],
            latitude: 10,
            longitude: 20,
            placeName: "Cay",
            userId: "11111111-1111-1111-1111-111111111111",
            username: "eddie",
            userProfileImageURL: "https://example.com/a.jpg",
            sourceDraftID: nil,
            vibeDisplayMode: .photoSynced
        )
        let posted = SpotPublishCoordinator.makePostedSpot(
            draft: draft,
            spotId: "22222222-2222-2222-2222-222222222222",
            signedFirstImage: "https://cdn.example/x.jpg",
            postedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(posted.vibeDisplayMode == .photoSynced)
        #expect(posted.photoSyncedVibeLabels == ["A", "B"])
        #expect(posted.authorIsPro == true)
        #expect(posted.mediaCount == 2)
        #expect(posted.imageURL == "https://cdn.example/x.jpg")
    }

    @Test func makePostedSpotRotatingOmitsSyncedLabels() {
        let draft = SpotPublishDraft(
            imageJPEGs: [Data([0xFF, 0xD8, 0xFF])],
            coverMediaDisplayAspectRatio: 1,
            vibeTags: ["Solo"],
            latitude: 1,
            longitude: 2,
            placeName: "Place",
            userId: "11111111-1111-1111-1111-111111111111",
            username: nil,
            userProfileImageURL: nil,
            sourceDraftID: nil,
            vibeDisplayMode: .rotating
        )
        let posted = SpotPublishCoordinator.makePostedSpot(
            draft: draft,
            spotId: "33333333-3333-3333-3333-333333333333",
            signedFirstImage: nil,
            postedAt: Date()
        )
        #expect(posted.vibeDisplayMode == .rotating)
        #expect(posted.photoSyncedVibeLabels == nil)
        #expect(posted.authorIsPro == false)
    }

    @Test func publishProgressMovesForwardAcrossMultiplePhotos() {
        let stages: [SpotPublishProgress] = [
            .preparing,
            .resolvingVibes,
            .uploadingPhoto(index: 0, total: 2),
            .checkingPhoto(index: 0, total: 2),
            .uploadingPhoto(index: 1, total: 2),
            .checkingPhoto(index: 1, total: 2),
            .publishing,
            .finalizing,
            .complete
        ]

        #expect(zip(stages, stages.dropFirst()).allSatisfy { pair in
            pair.0.fraction < pair.1.fraction
        })
        #expect(stages.last?.fraction == 1)
        #expect(SpotPublishProgress.uploadingPhoto(index: 1, total: 2).title == "Uploading photo 2 of 2…")
    }

    @Test func currentUserIdentityFillsMissingOptimisticAuthorFields() {
        let resolved = SpotAuthorDisplay.resolve(
            spotUsername: nil,
            spotProfileImageURL: nil,
            isCurrentUser: true,
            currentUsername: "eddie",
            currentProfileImageURL: "https://example.com/me.jpg"
        )

        #expect(resolved.username == "eddie")
        #expect(resolved.profileImageURL == "https://example.com/me.jpg")
    }

    @Test func anotherAuthorsIdentityNeverUsesCurrentUserFallback() {
        let resolved = SpotAuthorDisplay.resolve(
            spotUsername: nil,
            spotProfileImageURL: nil,
            isCurrentUser: false,
            currentUsername: "eddie",
            currentProfileImageURL: "https://example.com/me.jpg"
        )

        #expect(resolved == SpotAuthorDisplay(username: "User", profileImageURL: nil))
    }
}
