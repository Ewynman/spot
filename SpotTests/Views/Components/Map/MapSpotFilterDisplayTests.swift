//
//  MapSpotFilterDisplayTests.swift
//  SpotTests
//
//  Pro map filters remove non-matching pins from the displayed set.
//

import Testing
@testable import Spot

struct MapSpotFilterDisplayTests {

    private func spot(id: String, userId: String = "u1", vibe: String? = "Chill") -> Spot {
        Spot(id: id, userId: userId, vibeTag: vibe)
    }

    @Test func emptyFilterKeepsAllSpots() {
        let spots = [spot(id: "a"), spot(id: "b")]
        let out = SpotMapDisplayFilter.spotsToDisplay(
            spots,
            filter: .empty,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(out.count == 2)
    }

    @Test func vibeFilterKeepsOnlyMatchingTags() {
        let spots = [spot(id: "1", vibe: "Chill"), spot(id: "2", vibe: "Adventure")]
        let filter = SpotMapFilterState(dimensions: [.vibe], vibeTags: ["Chill"])
        let out = SpotMapDisplayFilter.spotsToDisplay(
            spots,
            filter: filter,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: []
        )
        #expect(out.map(\.id) == ["1"])
    }

    @Test func savedAndFollowingDimensionsAreAnded() {
        let spots = [
            Spot(id: "1", userId: "u1", vibeTag: "Chill"),
            Spot(id: "2", userId: "u2", vibeTag: "Chill")
        ]
        let filter = SpotMapFilterState(dimensions: [.saved, .following], vibeTags: [])
        let out = SpotMapDisplayFilter.spotsToDisplay(
            spots,
            filter: filter,
            savedSpotIds: ["1", "2"],
            likedSpotIds: [],
            followedUserIds: ["u1"]
        )
        #expect(out.map(\.id) == ["1"])
    }
}
