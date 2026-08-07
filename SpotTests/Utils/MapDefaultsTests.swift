//
//  MapDefaultsTests.swift
//  SpotTests
//
//  Locks down the App Review-mandated continental United States fallback
//  region used by the discovery map when CoreLocation cannot give us a
//  real fix (denied / restricted / disabled / unavailable). See
//  `Spot/Utils/MapDefaults.swift`.
//

import CoreLocation
import MapKit
import Testing
@testable import Spot

struct MapDefaultsTests {

    @Test func continentalUSCenterMatchesUSGSGeographicCenter() {
        let center = MapDefaults.continentalUSCenter
        #expect(abs(center.latitude - 39.8283) < 0.0001)
        #expect(abs(center.longitude - (-98.5795)) < 0.0001)
    }

    @Test func continentalUSSpanCoversLowerFortyEight() {
        let span = MapDefaults.continentalUSSpan
        #expect(span.latitudeDelta == 24.0)
        #expect(span.longitudeDelta == 58.0)
    }

    @Test func continentalUSRegionIsCenteredAndWide() {
        let region = MapDefaults.continentalUSRegion
        #expect(abs(region.center.latitude - 39.8283) < 0.0001)
        #expect(abs(region.center.longitude - (-98.5795)) < 0.0001)
        #expect(region.span.latitudeDelta > 20)
        #expect(region.span.longitudeDelta > 50)
    }

    // MARK: - LocationManager.initialRegion deterministic fallback

    @Test func initialRegionFallsBackToContinentalUSWhenLocationDenied() {
        let region = LocationManager.initialRegion(
            locationStatus: .denied,
            lastKnownLocation: nil
        )
        #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
        #expect(abs(region.center.longitude - MapDefaults.continentalUSCenter.longitude) < 0.0001)
    }

    @Test func initialRegionFallsBackToContinentalUSWhenLocationRestricted() {
        let region = LocationManager.initialRegion(
            locationStatus: .restricted,
            lastKnownLocation: nil
        )
        #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
        #expect(abs(region.center.longitude - MapDefaults.continentalUSCenter.longitude) < 0.0001)
    }

    @Test func initialRegionFallsBackToContinentalUSWhenLocationNotDetermined() {
        let region = LocationManager.initialRegion(
            locationStatus: .notDetermined,
            lastKnownLocation: nil
        )
        #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
    }

    @Test func initialRegionFallsBackToContinentalUSWhenAuthorizedButNoFix() {
        let region = LocationManager.initialRegion(
            locationStatus: .authorizedWhenInUse,
            lastKnownLocation: nil
        )
        #expect(abs(region.center.latitude - MapDefaults.continentalUSCenter.latitude) < 0.0001)
    }

    @Test func initialRegionUsesUserCoordinateWhenAuthorizedAndAvailable() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let region = LocationManager.initialRegion(
            locationStatus: .authorizedWhenInUse,
            lastKnownLocation: location,
            neighborhoodRadiusMeters: 3_200
        )
        #expect(abs(region.center.latitude - coordinate.latitude) < 0.0001)
        #expect(abs(region.center.longitude - coordinate.longitude) < 0.0001)
        // Neighborhood span should be much tighter than the continental US fallback.
        #expect(max(region.span.latitudeDelta, region.span.longitudeDelta) < 1.0)
    }

    @Test func initialRegionWhenAuthorizedAlwaysUsesUserCoordinate() {
        let coordinate = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let region = LocationManager.initialRegion(
            locationStatus: .authorizedAlways,
            lastKnownLocation: location
        )
        #expect(abs(region.center.latitude - coordinate.latitude) < 0.0001)
        #expect(abs(region.center.longitude - coordinate.longitude) < 0.0001)
    }
}
