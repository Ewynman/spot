//
//  MapDiscoveryDrawerPolicyTests.swift
//  SpotTests
//

import MapKit
import Testing
@testable import Spot

@Suite("Map discovery drawer policy")
struct MapDiscoveryDrawerPolicyTests {

    @Test("Identical regions do not differ meaningfully")
    func identicalNoDiff() {
        let r = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.76, longitude: -80.19),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        #expect(!MapDiscoveryDrawerPolicy.regionsMeaningfullyDiffer(r, r))
    }

    @Test("Pan large enough is meaningful")
    func panDiffers() {
        let a = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.76, longitude: -80.19),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let b = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.77, longitude: -80.19),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        #expect(MapDiscoveryDrawerPolicy.regionsMeaningfullyDiffer(a, b))
    }

    @Test("Zoom change large enough is meaningful")
    func zoomDiffers() {
        let a = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.76, longitude: -80.19),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let b = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.76, longitude: -80.19),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        #expect(MapDiscoveryDrawerPolicy.regionsMeaningfullyDiffer(a, b))
    }

    @Test("Suppression duration is positive")
    func suppressionPositive() {
        #expect(MapDiscoveryDrawerPolicy.programmaticCameraSuppressionSeconds > 0)
    }
}
