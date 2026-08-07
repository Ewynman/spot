//
//  VisibleSpotsTrimTests.swift
//  SpotTests
//
//  Guards the PRD §8 acceptance: "panning across several regions does not
//  grow `visibleSpots` indefinitely." `MapViewModel.trim` keeps the cap
//  honest by retaining the spots nearest to the latest viewport center.
//

import CoreLocation
import Foundation
import Testing
@testable import Spot

struct VisibleSpotsTrimTests {

    private func spot(_ id: String, _ lat: Double, _ lon: Double) -> Spot {
        Spot(id: id, userId: "u1", vibeTag: "Chill", latitude: lat, longitude: lon)
    }

    @Test func underCapReturnsAllSpots() {
        let spots = [spot("a", 40, -74), spot("b", 41, -75)]
        let trimmed = MapViewModel.trim(spots, near: CLLocationCoordinate2D(latitude: 40, longitude: -74), cap: 10)
        #expect(trimmed.count == 2)
    }

    @Test func overCapKeepsClosestSpotsToCenter() {
        // Center at (0, 0). Five spots with increasing distance.
        let spots = [
            spot("near0", 0.0, 0.0),
            spot("near1", 0.001, 0.0),
            spot("near2", 0.01, 0.0),
            spot("far1",  1.0, 0.0),
            spot("far2",  10.0, 0.0)
        ]
        let trimmed = MapViewModel.trim(spots, near: CLLocationCoordinate2D(latitude: 0, longitude: 0), cap: 3)
        #expect(trimmed.count == 3)
        let ids = Set(trimmed.compactMap { $0.id })
        #expect(ids == ["near0", "near1", "near2"])
    }

    @Test func zeroCapReturnsEmpty() {
        let spots = [spot("a", 0, 0)]
        let trimmed = MapViewModel.trim(spots, near: CLLocationCoordinate2D(latitude: 0, longitude: 0), cap: 0)
        #expect(trimmed.isEmpty)
    }

    @Test func spotsWithoutCoordinatesAreSortedLast() {
        // `trim` treats missing-coord spots as `.greatestFiniteMagnitude`
        // distance so they only occupy slots after geo-located spots.
        let spots = [
            spot("here", 0.0, 0.0),
            Spot(id: "noLoc", userId: "u1", vibeTag: "Chill")
        ]
        let trimmed = MapViewModel.trim(spots, near: CLLocationCoordinate2D(latitude: 0, longitude: 0), cap: 1)
        #expect(trimmed.count == 1)
        #expect(trimmed.first?.id == "here")
    }

    @Test func mergeRetainsExistingButPrefersFresh() {
        // Existing spot with stale URL.
        let stale = Spot(id: "s1", userId: "u1", vibeTag: "Chill", latitude: 0, longitude: 0)
        let fresh = Spot(id: "s1", userId: "u1", vibeTag: "Updated", latitude: 0, longitude: 0)
        let merged = MapViewModel.mergeRetainingExisting(current: [stale], fresh: [fresh])
        #expect(merged.count == 1)
        #expect(merged.first?.vibeTag == "Updated")
    }

    @Test func mergeAppendsNewIds() {
        let current = [Spot(id: "a", userId: "u1", vibeTag: "Chill")]
        let fresh = [Spot(id: "b", userId: "u1", vibeTag: "Adventure")]
        let merged = MapViewModel.mergeRetainingExisting(current: current, fresh: fresh)
        #expect(merged.count == 2)
        let ids = merged.compactMap { $0.id }
        #expect(ids == ["a", "b"])
    }
}
