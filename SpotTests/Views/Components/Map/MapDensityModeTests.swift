//
//  MapDensityModeTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import MapKit
import Testing
@testable import Spot

struct MapDensityModeTests {

    private func region(span: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    @Test func tightZoomReturnsIndividualPins() {
        let mode = MapDensityMode.mode(for: region(span: 0.005))
        #expect(mode == .individualPins)
    }

    @Test func cityZoomReturnsIndividualWithOverlap() {
        let mode = MapDensityMode.mode(for: region(span: 0.10))
        #expect(mode == .individualPinsWithSoftOverlap)
    }

    @Test func wideZoomReturnsSoftClusters() {
        let mode = MapDensityMode.mode(for: region(span: 1.0))
        #expect(mode == .softClusters)
    }

    @Test func mixedSpanUsesLargerDelta() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.5)
        )
        #expect(MapDensityMode.mode(for: region) == .softClusters)
    }

    @Test func boundaryAtLocalSpanIsIndividualPins() {
        let mode = MapDensityMode.mode(for: region(span: Constants.MapDesign.localSpan))
        #expect(mode == .individualPins)
    }

    @Test func boundaryAtCitySpanIsOverlapMode() {
        let mode = MapDensityMode.mode(for: region(span: Constants.MapDesign.citySpan))
        #expect(mode == .individualPinsWithSoftOverlap)
    }
}
