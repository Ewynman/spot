//
//  LocationManagerDelegateTests.swift
//  SpotTests
//

import CoreLocation
import MapKit
import Testing
@testable import Spot

@MainActor
struct LocationManagerDelegateTests {

    /// `LocationManager` persists its last good fix in standard `UserDefaults`.
    /// Snapshot and restore it so tests neither inherit nor leak a coordinate.
    private static let cacheKey = "spot.location.lastKnownGood"

    private func withCleanLocationCache<T>(_ body: (CLLocationManager) throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = defaults.dictionary(forKey: Self.cacheKey)
        defaults.removeObject(forKey: Self.cacheKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: Self.cacheKey)
            } else {
                defaults.removeObject(forKey: Self.cacheKey)
            }
        }
        // A throwaway CLLocationManager stands in for the sender argument; the
        // delegate methods under test only read `authorizationStatus` from it.
        return try body(CLLocationManager())
    }

    // MARK: - Delegate plumbing (the regression)

    @Test func locationFixFromDelegateUpdatesPublishedLocation() {
        withCleanLocationCache { sender in
            let manager = LocationManager()
            #expect(manager.userLocation == nil)

            let fix = CLLocation(latitude: 40.7128, longitude: -74.0060)
            manager.locationManager(sender, didUpdateLocations: [fix])

            #expect(manager.userLocation?.coordinate.latitude == 40.7128)
            #expect(manager.userLocation?.coordinate.longitude == -74.0060)
        }
    }

    /// CoreLocation batches fixes oldest-first; the newest one wins.
    @Test func mostRecentFixInABatchWins() {
        withCleanLocationCache { sender in
            let manager = LocationManager()
            manager.locationManager(sender, didUpdateLocations: [
                CLLocation(latitude: 1, longitude: 1),
                CLLocation(latitude: 2, longitude: 2),
                CLLocation(latitude: 3, longitude: 3)
            ])

            #expect(manager.userLocation?.coordinate.latitude == 3)
        }
    }

    @Test func emptyLocationBatchLeavesPreviousFixIntact() {
        withCleanLocationCache { sender in
            let manager = LocationManager()
            manager.locationManager(sender, didUpdateLocations: [
                CLLocation(latitude: 51.5074, longitude: -0.1278)
            ])
            manager.locationManager(sender, didUpdateLocations: [])

            #expect(manager.userLocation?.coordinate.latitude == 51.5074)
        }
    }

    /// A transient `kCLErrorLocationUnknown` must not wipe a good fix, or the
    /// map would drop back to the continental-US fallback mid-session.
    @Test func delegateFailureLeavesLastKnownFixIntact() {
        withCleanLocationCache { sender in
            let manager = LocationManager()
            manager.locationManager(sender, didUpdateLocations: [
                CLLocation(latitude: 34.0522, longitude: -118.2437)
            ])
            manager.locationManager(
                sender,
                didFailWithError: NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue)
            )

            #expect(manager.userLocation?.coordinate.latitude == 34.0522)
        }
    }

    // MARK: - Cross-session persistence

    @Test func fixFromDelegateSeedsTheNextInstanceFromDisk() {
        withCleanLocationCache { sender in
            let first = LocationManager()
            first.locationManager(sender, didUpdateLocations: [
                CLLocation(latitude: 48.8566, longitude: 2.3522)
            ])

            let next = LocationManager()
            #expect(next.userLocation?.coordinate.latitude == 48.8566)
            #expect(next.userLocation?.coordinate.longitude == 2.3522)
        }
    }

    @Test func freshInstallHasNoSeededLocation() {
        withCleanLocationCache { _ in
            let manager = LocationManager()
            #expect(manager.userLocation == nil)
        }
    }

    // MARK: - Region helpers

    @Test func userRegionCentersOnTheCurrentFix() {
        withCleanLocationCache { sender in
            let manager = LocationManager()
            manager.locationManager(sender, didUpdateLocations: [
                CLLocation(latitude: 37.7749, longitude: -122.4194)
            ])

            let region = manager.getUserRegion(radiusInMeters: 1000)
            #expect(abs(region.center.latitude - 37.7749) < 0.0001)
            #expect(abs(region.center.longitude - (-122.4194)) < 0.0001)
            #expect(region.span.latitudeDelta < MapDefaults.continentalUSSpan.latitudeDelta)
        }
    }

    /// App Review 5.1.5: with no fix the map still has to open somewhere
    /// browsable rather than a single unrelated city.
    @Test func userRegionFallsBackToContinentalUSWithoutAFix() {
        withCleanLocationCache { _ in
            let region = LocationManager().getUserRegion()
            #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
            #expect(abs(region.center.longitude - MapDefaults.continentalUSCenter.longitude) < 0.0001)
        }
    }

    @Test func regionForSpotsEnclosesEveryCoordinate() {
        withCleanLocationCache { _ in
            let spots = [
                makeSpot(id: "a", latitude: 40.0, longitude: -74.0),
                makeSpot(id: "b", latitude: 41.0, longitude: -73.0)
            ]
            let region = LocationManager().getRegionForSpots(spots)

            #expect(abs(region.center.latitude - 40.5) < 0.0001)
            #expect(abs(region.center.longitude - (-73.5)) < 0.0001)
            #expect(region.span.latitudeDelta >= 1.0)
            #expect(region.span.longitudeDelta >= 1.0)
        }
    }

    @Test func regionForSpotsFallsBackWhenNoSpotHasCoordinates() {
        withCleanLocationCache { _ in
            let region = LocationManager().getRegionForSpots([
                makeSpot(id: "a", latitude: nil, longitude: nil)
            ])
            #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
        }
    }

    @Test func regionForSpotsFallsBackWhenListIsEmpty() {
        withCleanLocationCache { _ in
            let region = LocationManager().getRegionForSpots([])
            #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
        }
    }

    // MARK: - Helpers

    private func makeSpot(id: String, latitude: Double?, longitude: Double?) -> Spot {
        Spot(
            id: id,
            userId: "u1",
            username: "tester",
            imageURL: nil,
            vibeTag: "Park",
            latitude: latitude,
            longitude: longitude,
            locationName: "Test",
            createdAt: Date()
        )
    }
}
