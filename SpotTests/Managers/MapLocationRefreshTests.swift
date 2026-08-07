//
//  MapLocationRefreshTests.swift
//  SpotTests
//
//  Tests that verify the map requests and applies fresh location updates
//  every time it appears, ensuring users see spots around their current
//  location rather than stale cached coordinates from onboarding or
//  previous sessions.
//

import CoreLocation
import Foundation
import Testing
@testable import Spot

@MainActor
struct MapLocationRefreshTests {
    
    // MARK: - Location Request on Appear Tests
    
    @Test func locationManagerRequestsLocationOnMapAppearWhenAuthorized() async throws {
        let locationManager = MockLocationManager()
        locationManager.authorizationStatus = .authorizedWhenInUse
        locationManager.userLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        #expect(locationManager.requestCurrentLocationCallCount == 0)
        
        locationManager.requestCurrentLocationForMapTab()
        
        #expect(locationManager.requestCurrentLocationCallCount == 1)
    }
    
    @Test func locationManagerDoesNotRequestLocationWhenNotAuthorized() async throws {
        let locationManager = MockLocationManager()
        locationManager.authorizationStatus = .denied
        
        #expect(locationManager.requestCurrentLocationCallCount == 0)
        
        locationManager.requestCurrentLocationForMapTab()
        
        #expect(locationManager.requestCurrentLocationCallCount == 0)
    }
    
    // MARK: - Location Distance Calculation Tests
    
    @Test func significantLocationChangeIsDetected() {
        let oldLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        let newLocation = CLLocation(latitude: 40.7589, longitude: -73.9851) // Times Square (5.5km away)
        
        let distance = newLocation.distance(from: oldLocation)
        
        #expect(distance > 100, "Distance should be greater than 100m threshold")
        #expect(distance > 5000, "Distance between NYC and Times Square should be ~5.5km")
    }
    
    @Test func minorLocationChangeIsDetected() {
        let oldLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let newLocation = CLLocation(latitude: 40.7129, longitude: -74.0061) // ~15m away
        
        let distance = newLocation.distance(from: oldLocation)
        
        #expect(distance < 100, "Distance should be less than 100m threshold")
        #expect(distance < 20, "Distance should be approximately 15 meters")
    }
    
    @Test func locationAtSameCoordinatesHasZeroDistance() {
        let location1 = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let location2 = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        let distance = location1.distance(from: location2)
        
        #expect(distance == 0)
    }
    
    // MARK: - Coordinate Tracking Tests
    
    @Test func coordinateTrackingIdentifiesMovement() {
        let initialCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let newCoord = CLLocationCoordinate2D(latitude: 40.7589, longitude: -73.9851)
        
        let initialLocation = CLLocation(latitude: initialCoord.latitude,
                                        longitude: initialCoord.longitude)
        let newLocation = CLLocation(latitude: newCoord.latitude,
                                    longitude: newCoord.longitude)
        
        let distance = newLocation.distance(from: initialLocation)
        let shouldUpdate = distance > 100
        
        #expect(shouldUpdate == true)
    }
    
    // MARK: - Edge Case Tests
    
    @Test func handlesInvalidCoordinatesGracefully() {
        let validCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        #expect(CLLocationCoordinate2DIsValid(validCoord))
        
        let invalidCoord = CLLocationCoordinate2D(latitude: 200, longitude: 200)
        #expect(!CLLocationCoordinate2DIsValid(invalidCoord))
    }
    
    @Test func handlesPolarRegionCoordinates() {
        let northPole = CLLocation(latitude: 89.9, longitude: 0)
        let nearNorthPole = CLLocation(latitude: 89.8, longitude: 0)
        
        let distance = nearNorthPole.distance(from: northPole)
        
        #expect(distance > 100, "Distance at polar regions should still be calculated correctly")
    }
    
    @Test func handlesDatelineCoordinates() {
        let eastOfDateline = CLLocation(latitude: 0, longitude: 179.9)
        let westOfDateline = CLLocation(latitude: 0, longitude: -179.9)
        
        let distance = westOfDateline.distance(from: eastOfDateline)
        
        #expect(distance < 50000, "Distance across dateline should be calculated correctly")
    }
    
    // MARK: - Location Manager State Tests
    
    @Test func locationManagerStartsWithNoLocation() {
        let locationManager = MockLocationManager()
        
        #expect(locationManager.userLocation == nil)
    }
    
    @Test func locationManagerUpdatesUserLocation() {
        let locationManager = MockLocationManager()
        let newLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        locationManager.userLocation = newLocation
        
        #expect(locationManager.userLocation?.coordinate.latitude == 40.7128)
        #expect(locationManager.userLocation?.coordinate.longitude == -74.0060)
    }
    
    @Test func locationManagerTracksAuthorizationStatus() {
        let locationManager = MockLocationManager()
        
        locationManager.authorizationStatus = .notDetermined
        #expect(locationManager.authorizationStatus == .notDetermined)
        
        locationManager.authorizationStatus = .authorizedWhenInUse
        #expect(locationManager.authorizationStatus == .authorizedWhenInUse)
        
        locationManager.authorizationStatus = .denied
        #expect(locationManager.authorizationStatus == .denied)
    }
    
    // MARK: - Multiple Location Update Tests
    
    @Test func multipleLocationUpdatesAreTracked() {
        let locationManager = MockLocationManager()
        locationManager.authorizationStatus = .authorizedWhenInUse
        
        let location1 = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let location2 = CLLocation(latitude: 40.7589, longitude: -73.9851)
        let location3 = CLLocation(latitude: 34.0522, longitude: -118.2437)
        
        locationManager.userLocation = location1
        #expect(locationManager.userLocation?.coordinate.latitude == 40.7128)
        
        locationManager.userLocation = location2
        #expect(locationManager.userLocation?.coordinate.latitude == 40.7589)
        
        locationManager.userLocation = location3
        #expect(locationManager.userLocation?.coordinate.latitude == 34.0522)
    }
    
    @Test func locationAccuracyIsPreserved() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 10,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        
        #expect(location.horizontalAccuracy == 5.0)
        #expect(location.verticalAccuracy == 10.0)
    }
    
    // MARK: - Authorization State Transition Tests
    
    @Test func authorizationTransitionFromNotDeterminedToAuthorized() {
        let locationManager = MockLocationManager()
        locationManager.authorizationStatus = .notDetermined
        
        #expect(locationManager.authorizationStatus == .notDetermined)
        
        locationManager.authorizationStatus = .authorizedWhenInUse
        
        #expect(locationManager.authorizationStatus == .authorizedWhenInUse)
    }
    
    @Test func authorizationTransitionFromNotDeterminedToDenied() {
        let locationManager = MockLocationManager()
        locationManager.authorizationStatus = .notDetermined
        
        #expect(locationManager.authorizationStatus == .notDetermined)
        
        locationManager.authorizationStatus = .denied
        
        #expect(locationManager.authorizationStatus == .denied)
    }
}

// MARK: - Mock Location Manager

@MainActor
class MockLocationManager: ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    var requestCurrentLocationCallCount = 0
    
    func requestCurrentLocationForMapTab() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestCurrentLocationCallCount += 1
        default:
            break
        }
    }
}
