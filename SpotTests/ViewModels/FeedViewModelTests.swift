//
//  FeedViewModelTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Foundation
import Testing
@testable import Spot

struct FeedViewModelTests {

    private func makeSpot(id: String? = "s1", lat: Double? = nil, lon: Double? = nil) -> Spot {
        Spot(id: id, userId: "u1", vibeTag: "Chill", latitude: lat, longitude: lon, createdAt: Date())
    }

    @Test func validSpotsReturnsSpotsUnfiltered() {
        let vm = FeedViewModel()
        let spot1 = makeSpot(id: "a", lat: 40.0, lon: -74.0)
        let spot2 = makeSpot(id: "b", lat: nil, lon: nil)
        vm.spots = [spot1, spot2]
        let validSpots = vm.validSpots
        #expect(validSpots.map(\.id) == ["a", "b"])
    }

    @Test func validMapSpotsFiltersOutSpotsWithoutCoordinates() {
        let vm = FeedViewModel()
        let withCoords = makeSpot(id: "with", lat: 40.0, lon: -74.0)
        let noLat = makeSpot(id: "noLat", lat: nil, lon: -74.0)
        let noLon = makeSpot(id: "noLon", lat: 40.0, lon: nil)
        let noCoords = makeSpot(id: "noCoords", lat: nil, lon: nil)
        vm.mapSpots = [withCoords, noLat, noLon, noCoords]
        #expect(vm.validMapSpots.count == 1)
        #expect(vm.validMapSpots[0].id == "with")
    }

    @Test func validMapSpotsIncludesAllWhenAllHaveCoordinates() {
        let vm = FeedViewModel()
        let s1 = makeSpot(id: "1", lat: 40.0, lon: -74.0)
        let s2 = makeSpot(id: "2", lat: 41.0, lon: -73.0)
        vm.mapSpots = [s1, s2]
        #expect(vm.validMapSpots.count == 2)
    }

    @Test func validMapSpotsEmptyWhenMapSpotsEmpty() {
        let vm = FeedViewModel()
        vm.mapSpots = []
        #expect(vm.validMapSpots.isEmpty)
    }
}
