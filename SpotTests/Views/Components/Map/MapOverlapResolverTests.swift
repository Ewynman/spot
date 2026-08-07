//
//  MapOverlapResolverTests.swift
//  SpotTests
//
//  `MapOverlapResolver` resolves two-or-more spots posted at "the same
//  place" by quantizing their lat/lon into ~5 m buckets and pushing the
//  extras onto a small radial ring. These tests pin down:
//   * isolated spots are not moved,
//   * overlapping spots get unique coordinates (no collapsed bullseye),
//   * the resolver is deterministic on `spot.id` (same input → same output).
//

import CoreLocation
import Foundation
import Testing
@testable import Spot

struct MapOverlapResolverTests {

    private func spot(_ id: String, _ lat: Double, _ lon: Double) -> Spot {
        Spot(id: id, userId: "u1", vibeTag: "Chill", latitude: lat, longitude: lon)
    }

    @Test func nonOverlappingSpotsKeepCoordinates() {
        let spots = [
            spot("a", 40.0, -74.0),
            spot("b", 41.0, -75.0)
        ]
        let resolved = MapOverlapResolver().resolve(spots)
        #expect(resolved.count == 2)
        for entry in resolved {
            if entry.spot.id == "a" {
                #expect(entry.coordinate.latitude == 40.0)
                #expect(entry.coordinate.longitude == -74.0)
            }
            if entry.spot.id == "b" {
                #expect(entry.coordinate.latitude == 41.0)
                #expect(entry.coordinate.longitude == -75.0)
            }
        }
    }

    @Test func overlappingSpotsAreFannedOut() {
        // Three spots at virtually the same lat/lon → resolver must hand
        // back three distinct coordinates.
        let spots = [
            spot("a", 40.0, -74.0),
            spot("b", 40.0, -74.0),
            spot("c", 40.000001, -74.000001)
        ]
        let resolved = MapOverlapResolver().resolve(spots)
        #expect(resolved.count == 3)

        let coords = resolved.map { ($0.coordinate.latitude, $0.coordinate.longitude) }
        var seen: Set<String> = []
        for (lat, lon) in coords {
            seen.insert(String(format: "%.7f,%.7f", lat, lon))
        }
        #expect(seen.count == 3)
    }

    @Test func resolverIsDeterministic() {
        let spots = [
            spot("a", 40.0, -74.0),
            spot("b", 40.0, -74.0),
            spot("c", 40.0, -74.0)
        ]
        let r1 = MapOverlapResolver().resolve(spots)
        let r2 = MapOverlapResolver().resolve(spots)
        #expect(r1.count == r2.count)
        for i in 0..<r1.count {
            #expect(r1[i].spot.id == r2[i].spot.id)
            #expect(r1[i].coordinate.latitude == r2[i].coordinate.latitude)
            #expect(r1[i].coordinate.longitude == r2[i].coordinate.longitude)
        }
    }

    @Test func bucketStatsCountsMultiBuckets() {
        let spots = [
            spot("a", 40.0, -74.0),
            spot("b", 40.0, -74.0),
            spot("c", 41.0, -74.0),
            spot("d", 50.0, -100.0)
        ]
        let stats = MapOverlapResolver().bucketStats(spots)
        #expect(stats.totalBuckets == 3)
        #expect(stats.multiBuckets == 1)
        #expect(stats.maxMembers == 2)
    }

    @Test func spotsWithoutCoordinatesAreDropped() {
        let spots = [
            spot("a", 40.0, -74.0),
            Spot(id: "b", userId: "u1", vibeTag: "Chill")
        ]
        let resolved = MapOverlapResolver().resolve(spots)
        #expect(resolved.count == 1)
        #expect(resolved.first?.spot.id == "a")
    }
}
