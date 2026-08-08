//
//  SpotMarkerStyleTests.swift
//  SpotTests
//
//  Locks down `SpotMarkerStyleResolver` — the pure function that decides a
//  spot pin's visual state given the active filter, the current selection,
//  and the viewer's saved/liked/follow lists.
//
//  Discovery map rendering removes non-matching pins entirely; the resolver
//  is still used for `matches(...)` and for match styling on visible pins.
//

import Foundation
import Testing
@testable import Spot

struct SpotMarkerStyleTests {

    private func spot(id: String = "s1",
                      userId: String = "u1",
                      vibeTag: String? = "Chill") -> Spot {
        Spot(id: id, userId: userId, vibeTag: vibeTag)
    }

    @Test func selectedAlwaysWinsOverFilter() {
        let s = spot()
        let filter = SpotMapFilterState(dimensions: [.saved], vibeTags: [])
        let state = SpotMarkerStyleResolver.state(
            for: s,
            selectedSpotId: "s1",
            filter: filter,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(state == .selected)
    }

    @Test func emptyFilterReturnsDefault() {
        let state = SpotMarkerStyleResolver.state(
            for: spot(),
            selectedSpotId: nil,
            filter: .empty,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(state == .default)
    }

    @Test func vibeFilterMatchProducesFilterMatch() {
        let filter = SpotMapFilterState(dimensions: [.vibe], vibeTags: ["Chill"])
        let state = SpotMarkerStyleResolver.state(
            for: spot(vibeTag: "Chill"),
            selectedSpotId: nil,
            filter: filter,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(state == .filterMatch)
    }

    @Test func vibeTagNotInSelectedVibesDoesNotMatch() {
        let filter = SpotMapFilterState(dimensions: [.vibe], vibeTags: ["Adventure"])
        #expect(!SpotMarkerStyleResolver.matches(
            spot(vibeTag: "Chill"),
            filter: filter,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        ))
    }

    @Test func activeFilterVisibleSpotUsesFilterMatchVisualState() {
        let filter = SpotMapFilterState(dimensions: [.vibe], vibeTags: ["Chill"])
        let state = SpotMarkerStyleResolver.state(
            for: spot(vibeTag: "Chill"),
            selectedSpotId: nil,
            filter: filter,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(state == .filterMatch)
    }

    @Test func savedFilterRequiresMembership() {
        let filter = SpotMapFilterState(dimensions: [.saved], vibeTags: [])
        let saved: Set<String> = ["s1"]
        let matched = SpotMarkerStyleResolver.matches(
            spot(),
            filter: filter,
            savedSpotIds: saved,
            likedSpotIds: [],
            followedUserIds: []
        )
        let unmatched = SpotMarkerStyleResolver.matches(
            spot(id: "s2"),
            filter: filter,
            savedSpotIds: saved,
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(matched == true)
        #expect(unmatched == false)
    }

    @Test func multipleDimensionsAreANDed() {
        let filter = SpotMapFilterState(
            dimensions: [.saved, .following],
            vibeTags: []
        )
        let saved: Set<String> = ["s1"]
        let followed: Set<String> = ["u1"]
        // Saved + following → match.
        let m1 = SpotMarkerStyleResolver.matches(
            spot(),
            filter: filter,
            savedSpotIds: saved,
            likedSpotIds: [],
            followedUserIds: followed
        )
        // Saved but not following → reject.
        let m2 = SpotMarkerStyleResolver.matches(
            spot(),
            filter: filter,
            savedSpotIds: saved,
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(m1 == true)
        #expect(m2 == false)
    }

    @Test func likedFilterRequiresMembership() {
        let filter = SpotMapFilterState(dimensions: [.liked], vibeTags: [])
        let liked: Set<String> = ["s1"]
        #expect(SpotMarkerStyleResolver.matches(spot(), filter: filter, savedSpotIds: [], likedSpotIds: liked, followedUserIds: []))
        #expect(!SpotMarkerStyleResolver.matches(spot(id: "s2"), filter: filter, savedSpotIds: [], likedSpotIds: liked, followedUserIds: []))
    }

    @Test func emptyVibeTagsRejectVibeDimension() {
        // Vibe dim is on but no tags chosen — every spot is a non-match.
        let filter = SpotMapFilterState(dimensions: [.vibe], vibeTags: [])
        #expect(!SpotMarkerStyleResolver.matches(
            spot(vibeTag: "Chill"),
            filter: filter,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        ))
    }
}
