//
//  SpotModelTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Testing
@testable import Spot

struct SpotModelTests {

    @Test func displayVibeTagsPrefersVibeTagsArray() {
        let spot = Spot(
            id: "1",
            vibeTag: "Solo",
            vibeTags: ["Foodie", "Quiet Moment"]
        )
        #expect(spot.displayVibeTags == ["Foodie", "Quiet Moment"])
    }

    @Test func displayVibeTagsFallsBackToSingleVibeTag() {
        let spot = Spot(id: "2", vibeTag: "Beach Day", vibeTags: nil)
        #expect(spot.displayVibeTags == ["Beach Day"])
    }

    @Test func displayVibeTagsEmptyWhenUnset() {
        let spot = Spot(id: "3")
        #expect(spot.displayVibeTags.isEmpty)
    }
}
