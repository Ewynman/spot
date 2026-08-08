//
//  MapCameraRegionTests.swift
//  SpotTests
//
//  Ensures the discovery map's first user-centered region stays at
//  neighborhood zoom (not a continental/world span).
//

import CoreLocation
import MapKit
import Testing
@testable import Spot

struct MapCameraRegionTests {

    @Test func neighborhoodSpanIsTightAroundNYC() {
        let center = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let region = MapCameraRegion.neighborhood(
            center: center,
            radiusMeters: Constants.MapDesign.initialNeighborhoodRadiusMeters
        )
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        #expect(span > 0)
        #expect(span < 0.05, "Neighborhood zoom should be well below city-wide span")
    }
}
