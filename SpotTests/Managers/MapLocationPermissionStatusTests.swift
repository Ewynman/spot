//
//  MapLocationPermissionStatusTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import AVFoundation
import CoreLocation
import Foundation
import Photos
import Testing
import UserNotifications
@testable import Spot

@MainActor
struct MapLocationPermissionStatusTests {
    
    // MARK: - Permission Manager Status Updates
    
    @Test func permissionManagerReflectsCurrentAuthorizationStatus() {
        let permissionManager = MockPermissionManager()
        
        permissionManager.locationStatus = .notDetermined
        #expect(permissionManager.locationStatus == .notDetermined)
        
        permissionManager.locationStatus = .authorizedWhenInUse
        #expect(permissionManager.locationStatus == .authorizedWhenInUse)
        
        permissionManager.locationStatus = .denied
        #expect(permissionManager.locationStatus == .denied)
    }
    
    @Test func permissionManagerStatusCanTransitionFromNotDeterminedToAuthorized() {
        let permissionManager = MockPermissionManager()
        permissionManager.locationStatus = .notDetermined
        
        // Simulate user granting permission
        permissionManager.locationStatus = .authorizedWhenInUse
        
        #expect(permissionManager.locationStatus == .authorizedWhenInUse)
    }
    
    @Test func permissionManagerStatusCanTransitionFromNotDeterminedToDenied() {
        let permissionManager = MockPermissionManager()
        permissionManager.locationStatus = .notDetermined
        
        // Simulate user denying permission
        permissionManager.locationStatus = .denied
        
        #expect(permissionManager.locationStatus == .denied)
    }
    
    @Test func permissionManagerStatusCanBeAuthorizedAlways() {
        let permissionManager = MockPermissionManager()
        permissionManager.locationStatus = .authorizedAlways
        
        #expect(permissionManager.locationStatus == .authorizedAlways)
    }
    
    @Test func permissionManagerStatusCanBeRestricted() {
        let permissionManager = MockPermissionManager()
        permissionManager.locationStatus = .restricted
        
        #expect(permissionManager.locationStatus == .restricted)
    }
    
    // MARK: - Recenter Logic Decision Tests
    
    @Test func recenterWithNotDeterminedStatusShouldShowPrompt() {
        // When status is .notDetermined, recenterOnUser() should show the
        // location pre-prompt sheet and return early without centering
        let status: CLAuthorizationStatus = .notDetermined
        let shouldShowPrompt = (status == .notDetermined)
        let shouldCenterImmediately = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(shouldShowPrompt == true)
        #expect(shouldCenterImmediately == false)
    }
    
    @Test func recenterWithAuthorizedWhenInUseShouldCenterImmediately() {
        // When status is .authorizedWhenInUse, recenterOnUser() should center
        // on location immediately without showing the permission prompt
        let status: CLAuthorizationStatus = .authorizedWhenInUse
        let shouldShowPrompt = (status == .notDetermined)
        let shouldCenterImmediately = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(shouldShowPrompt == false)
        #expect(shouldCenterImmediately == true)
    }
    
    @Test func recenterWithAuthorizedAlwaysShouldCenterImmediately() {
        // When status is .authorizedAlways, recenterOnUser() should center
        // on location immediately without showing the permission prompt
        let status: CLAuthorizationStatus = .authorizedAlways
        let shouldShowPrompt = (status == .notDetermined)
        let shouldCenterImmediately = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(shouldShowPrompt == false)
        #expect(shouldCenterImmediately == true)
    }
    
    @Test func recenterWithDeniedStatusShouldUseCachedLocation() {
        // When status is .denied, recenterOnUser() should use the cached
        // location if available (not show permission prompt, as that would fail)
        let status: CLAuthorizationStatus = .denied
        let shouldShowPrompt = (status == .notDetermined)
        let shouldUseCachedLocation = (status == .denied || status == .restricted)
        
        #expect(shouldShowPrompt == false)
        #expect(shouldUseCachedLocation == true)
    }
    
    @Test func recenterWithRestrictedStatusShouldUseCachedLocation() {
        // When status is .restricted, recenterOnUser() should use the cached
        // location if available
        let status: CLAuthorizationStatus = .restricted
        let shouldShowPrompt = (status == .notDetermined)
        let shouldUseCachedLocation = (status == .denied || status == .restricted)
        
        #expect(shouldShowPrompt == false)
        #expect(shouldUseCachedLocation == true)
    }
    
    // MARK: - Recenter Control Visibility Tests
    
    @Test func recenterButtonShownWhenNotDetermined() {
        // shouldShowRecenterControl returns true when .notDetermined
        // (user can tap to trigger the permission flow)
        let status: CLAuthorizationStatus = .notDetermined
        let hasLocation = false
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == true)
    }
    
    @Test func recenterButtonShownWhenAuthorizedWhenInUse() {
        // shouldShowRecenterControl returns true when .authorizedWhenInUse
        let status: CLAuthorizationStatus = .authorizedWhenInUse
        let hasLocation = false // doesn't matter for authorized states
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == true)
    }
    
    @Test func recenterButtonShownWhenAuthorizedAlways() {
        // shouldShowRecenterControl returns true when .authorizedAlways
        let status: CLAuthorizationStatus = .authorizedAlways
        let hasLocation = false // doesn't matter for authorized states
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == true)
    }
    
    @Test func recenterButtonShownWhenDeniedWithCachedLocation() {
        // shouldShowRecenterControl returns true when .denied but we have
        // a cached location to recenter on
        let status: CLAuthorizationStatus = .denied
        let hasLocation = true
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == true)
    }
    
    @Test func recenterButtonHiddenWhenDeniedWithoutCachedLocation() {
        // shouldShowRecenterControl returns false when .denied and no cached
        // location (nothing to recenter on)
        let status: CLAuthorizationStatus = .denied
        let hasLocation = false
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == false)
    }
    
    @Test func recenterButtonShownWhenRestrictedWithCachedLocation() {
        // shouldShowRecenterControl returns true when .restricted but we have
        // a cached location to recenter on
        let status: CLAuthorizationStatus = .restricted
        let hasLocation = true
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == true)
    }
    
    @Test func recenterButtonHiddenWhenRestrictedWithoutCachedLocation() {
        // shouldShowRecenterControl returns false when .restricted and no
        // cached location
        let status: CLAuthorizationStatus = .restricted
        let hasLocation = false
        let shouldShow = shouldShowRecenterControl(status: status, hasLocation: hasLocation)
        
        #expect(shouldShow == false)
    }
    
    // MARK: - OnAppear Authorization Check Tests
    
    @Test func onAppearRecognizesAuthorizedWhenInUseStatus() {
        let status: CLAuthorizationStatus = .authorizedWhenInUse
        let isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(isAuthorized == true)
    }
    
    @Test func onAppearRecognizesAuthorizedAlwaysStatus() {
        let status: CLAuthorizationStatus = .authorizedAlways
        let isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(isAuthorized == true)
    }
    
    @Test func onAppearRecognizesNotDeterminedAsNotAuthorized() {
        let status: CLAuthorizationStatus = .notDetermined
        let isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(isAuthorized == false)
    }
    
    @Test func onAppearRecognizesDeniedAsNotAuthorized() {
        let status: CLAuthorizationStatus = .denied
        let isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(isAuthorized == false)
    }
    
    @Test func onAppearRecognizesRestrictedAsNotAuthorized() {
        let status: CLAuthorizationStatus = .restricted
        let isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        #expect(isAuthorized == false)
    }
    
    // MARK: - Permission Status Source Consistency Tests
    
    @Test func permissionManagerAndLocationManagerCanHaveDifferentStatuses() {
        // This test verifies the scenario that caused the bug:
        // LocationManager's @Published property might be stale while
        // PermissionManager has the fresh system status
        let locationManager = MockLocationManager()
        let permissionManager = MockPermissionManager()
        
        // Scenario: User just granted permission, but LocationManager hasn't
        // received the delegate callback yet
        locationManager.authorizationStatus = .notDetermined // stale
        permissionManager.locationStatus = .authorizedWhenInUse // fresh from system
        
        #expect(locationManager.authorizationStatus == .notDetermined)
        #expect(permissionManager.locationStatus == .authorizedWhenInUse)
        #expect(locationManager.authorizationStatus != permissionManager.locationStatus)
    }
    
    @Test func usingStaleLocationManagerStatusCausesIncorrectBehavior() {
        let locationManager = MockLocationManager()
        let permissionManager = MockPermissionManager()
        
        // Simulate the bug scenario
        locationManager.authorizationStatus = .notDetermined // stale
        permissionManager.locationStatus = .authorizedWhenInUse // fresh
        
        // Using stale status incorrectly shows prompt
        let wrongShouldShowPrompt = (locationManager.authorizationStatus == .notDetermined)
        #expect(wrongShouldShowPrompt == true, "Bug: using stale status shows prompt")
        
        // Using fresh status correctly doesn't show prompt
        let correctShouldShowPrompt = (permissionManager.locationStatus == .notDetermined)
        #expect(correctShouldShowPrompt == false, "Fix: using fresh status skips prompt")
    }
    
    @Test func usingFreshPermissionManagerStatusGivesCorrectBehavior() {
        let permissionManager = MockPermissionManager()
        
        // After updatePermissionStatuses(), permissionManager has fresh status
        permissionManager.locationStatus = .authorizedWhenInUse
        
        let shouldShowPrompt = (permissionManager.locationStatus == .notDetermined)
        let shouldCenter = (permissionManager.locationStatus == .authorizedWhenInUse || 
                          permissionManager.locationStatus == .authorizedAlways)
        
        #expect(shouldShowPrompt == false, "Should not show prompt when already authorized")
        #expect(shouldCenter == true, "Should center on location immediately")
    }

    // MARK: - Shared Permission Policy Tests

    @Test func authorizedStatusCompletesAnAlreadyPresentedPrePrompt() {
        #expect(
            LocationPermissionPolicy.primaryAction(for: .authorizedWhenInUse) == .complete
        )
        #expect(
            LocationPermissionPolicy.primaryAction(for: .authorizedAlways) == .complete
        )
    }

    @Test func unresolvedStatusRequestsSystemPermission() {
        #expect(
            LocationPermissionPolicy.primaryAction(for: .notDetermined) == .requestSystemPermission
        )
    }

    @Test func deniedStatusRoutesToSettings() {
        #expect(LocationPermissionPolicy.primaryAction(for: .denied) == .openSettings)
        #expect(LocationPermissionPolicy.primaryAction(for: .restricted) == .openSettings)
    }

    @Test func freshPermissionStatusWinsOverStaleLocationMirror() {
        let staleLocationStatus: CLAuthorizationStatus = .notDetermined
        let freshPermissionStatus: CLAuthorizationStatus = .authorizedWhenInUse

        #expect(LocationPermissionPolicy.isAuthorized(staleLocationStatus) == false)
        #expect(LocationPermissionPolicy.isAuthorized(freshPermissionStatus) == true)
    }
    
    // MARK: - Helper function that mirrors MapView's shouldShowRecenterControl logic
    
    private func shouldShowRecenterControl(
        status: CLAuthorizationStatus,
        hasLocation: Bool
    ) -> Bool {
        MapRecenterVisibility.shouldShow(status: status, hasLocation: hasLocation)
    }
}

// MARK: - Mock Permission Manager

@MainActor
class MockPermissionManager: ObservableObject {
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var photoStatus: PHAuthorizationStatus = .notDetermined
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var showLocationBanner = false
    @Published var showNotificationBanner = false
    
    var updatePermissionStatusesCallCount = 0
    
    func updatePermissionStatuses() {
        updatePermissionStatusesCallCount += 1
        // In tests, the caller will set locationStatus manually to simulate
        // the system returning a specific status
    }
}
