//
//  MapViewModelStateTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Pure-state coverage for MapViewModel that does not require Supabase /
//  MapKit IO. The geo trim/merge functions are exercised in
//  `VisibleSpotsTrimTests`; this suite focuses on the lifecycle
//  expectations BottomTabNavigationView and MapView depend on.
//

import CoreLocation
import Foundation
import Testing
@testable import Spot

@MainActor
struct MapViewModelStateTests {

    @Test func defaultStateIsEmptyAndNotLoading() {
        let vm = MapViewModel()
        #expect(vm.visibleSpots.isEmpty)
        #expect(vm.isLoadingAllSpots == false)
    }

    @Test func clearVisibleSpotsWipesCachedSpots() {
        let vm = MapViewModel()
        vm.visibleSpots = [
            SpotTestHelpers.makeSpot(id: "a", latitude: 0, longitude: 0),
            SpotTestHelpers.makeSpot(id: "b", latitude: 1, longitude: 1)
        ]
        vm.clearVisibleSpots()
        #expect(vm.visibleSpots.isEmpty)
    }

    @Test func clearVisibleSpotsIsIdempotent() {
        let vm = MapViewModel()
        vm.clearVisibleSpots()
        vm.clearVisibleSpots()
        #expect(vm.visibleSpots.isEmpty)
    }

    @Test func mergePreservesOrderForOverlappingIds() {
        let current = [
            SpotTestHelpers.makeSpot(id: "a"),
            SpotTestHelpers.makeSpot(id: "b"),
            SpotTestHelpers.makeSpot(id: "c")
        ]
        let fresh = [
            SpotTestHelpers.makeSpot(id: "b", vibeTag: "Updated"),
            SpotTestHelpers.makeSpot(id: "d")
        ]
        let merged = MapViewModel.mergeRetainingExisting(current: current, fresh: fresh)
        let ids = merged.compactMap { $0.id }
        #expect(ids == ["a", "b", "c", "d"])
        #expect(merged.first(where: { $0.id == "b" })?.vibeTag == "Updated")
    }

    @Test func mergeIgnoresEntriesWithMissingId() {
        let current = [SpotTestHelpers.makeSpot(id: nil), SpotTestHelpers.makeSpot(id: "a")]
        let fresh = [SpotTestHelpers.makeSpot(id: nil), SpotTestHelpers.makeSpot(id: "b")]
        let merged = MapViewModel.mergeRetainingExisting(current: current, fresh: fresh)
        let ids = merged.compactMap { $0.id }
        #expect(ids == ["a", "b"])
    }

    @Test func trimWithEmptyArrayReturnsEmpty() {
        let trimmed = MapViewModel.trim(
            [],
            near: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            cap: 5
        )
        #expect(trimmed.isEmpty)
    }
}
