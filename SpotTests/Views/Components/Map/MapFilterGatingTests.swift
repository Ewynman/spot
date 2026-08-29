//
//  MapFilterGatingTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Testing
@testable import Spot

struct MapFilterGatingTests {

    @Test func proUserSeesFilterUI() {
        #expect(MapFilterGate.isAvailable(isPro: true) == true)
    }

    @Test func nonProUserDoesNotSeeFilterUI() {
        #expect(MapFilterGate.isAvailable(isPro: false) == false)
    }

    @Test func emptyFilterStateIsNotActive() {
        #expect(SpotMapFilterState.empty.isActive == false)
    }

    @Test func filterStateWithDimensionIsActive() {
        let s = SpotMapFilterState(dimensions: [.saved], vibeTags: [])
        #expect(s.isActive == true)
    }

    @Test func filterStateWithVibeTagsButNoDimensionIsInactive() {
        // Vibe tags only count when the `.vibe` dimension is also enabled.
        let s = SpotMapFilterState(dimensions: [], vibeTags: ["Chill"])
        #expect(s.isActive == false)
    }
}
