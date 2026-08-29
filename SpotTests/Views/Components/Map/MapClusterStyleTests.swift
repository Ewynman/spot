//
//  MapClusterStyleTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreLocation
import MapKit
import Testing
@testable import Spot

struct MapClusterStyleTests {

    @Test func sizeBucketsAreDiscrete() {
        #expect(MapClusterStyle.sizeBucket(forCount: 1) == .small)
        #expect(MapClusterStyle.sizeBucket(forCount: 9) == .small)
        #expect(MapClusterStyle.sizeBucket(forCount: 10) == .medium)
        #expect(MapClusterStyle.sizeBucket(forCount: 99) == .medium)
        #expect(MapClusterStyle.sizeBucket(forCount: 100) == .large)
        #expect(MapClusterStyle.pointSize(forCount: 5) == Constants.MapDesign.clusterSizeSmall)
        #expect(MapClusterStyle.pointSize(forCount: 50) == Constants.MapDesign.clusterSizeMedium)
        #expect(MapClusterStyle.pointSize(forCount: 120) == Constants.MapDesign.clusterSizeLarge)
    }

    @Test func countLabelCapsAt999() {
        #expect(MapClusterStyle.countLabel(forCount: 23) == "23")
        #expect(MapClusterStyle.countLabel(forCount: 1000) == "999+")
    }

    @Test func coincidentWhenMembersShareCoordinate() {
        let a = MKPointAnnotation()
        a.coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = MKPointAnnotation()
        b.coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        #expect(MapClusterStyle.isCoincident([a, b]))
    }

    @Test func notCoincidentWhenMembersAreSeparated() {
        let a = MKPointAnnotation()
        a.coordinate = CLLocationCoordinate2D(latitude: 40.71, longitude: -74.00)
        let b = MKPointAnnotation()
        b.coordinate = CLLocationCoordinate2D(latitude: 40.73, longitude: -74.02)
        #expect(!MapClusterStyle.isCoincident([a, b]))
    }

    @Test func compactPreviewCameraLiftUsesCardHeight() {
        let lift = MapClusterStyle.compactPreviewCameraLift(cardHeight: 200)
        #expect(lift >= Constants.MapDesign.selectedPinCameraLift)
        #expect(abs(lift - 110) < 0.001)
    }

    @Test func pinSelectedScaleIsRestrained() {
        #expect(Constants.MapDesign.pinSelectedScale == 1.15)
        #expect(Constants.MapDesign.compactPreviewHeight <= 140)
    }
}
