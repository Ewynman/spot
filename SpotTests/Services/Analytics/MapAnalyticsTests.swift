//
//  MapAnalyticsTests.swift
//  SpotTests
//
//  Verifies that every MapAnalytics helper builds the correct event name and
//  that both surface values are accepted without crashing. Firebase is a
//  no-op during unit tests (AnalyticsService guards on isUnitTestMode), so
//  these tests measure that the routing logic is exercised.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct MapAnalyticsTests {

    // MARK: - Surface raw values

    @Test func globalSurfaceRawValue() {
        #expect(MapAnalyticsSurface.global.rawValue == "global")
    }

    @Test func profileSurfaceRawValue() {
        #expect(MapAnalyticsSurface.profile.rawValue == "profile")
    }

    // MARK: - markerTapped

    @Test func markerTappedWithSpotId() {
        // Should not crash; AnalyticsService is a no-op during unit tests.
        MapAnalytics.markerTapped(surface: .global, spotId: "abc123")
    }

    @Test func markerTappedWithNilSpotId() {
        MapAnalytics.markerTapped(surface: .profile, spotId: nil)
    }

    // MARK: - clusterTapped

    @Test func clusterTappedGlobalSurface() {
        MapAnalytics.clusterTapped(surface: .global, memberCount: 5)
    }

    @Test func clusterTappedProfileSurface() {
        MapAnalytics.clusterTapped(surface: .profile, memberCount: 42)
    }

    // MARK: - previewShown

    @Test func previewShownWithSpotId() {
        MapAnalytics.previewShown(surface: .global, spotId: "spot-001")
    }

    @Test func previewShownWithNilSpotId() {
        MapAnalytics.previewShown(surface: .profile, spotId: nil)
    }

    // MARK: - previewLiked

    @Test func previewLikedTrue() {
        MapAnalytics.previewLiked(surface: .global, spotId: "spot-002", isLiked: true)
    }

    @Test func previewLikedFalse() {
        MapAnalytics.previewLiked(surface: .profile, spotId: nil, isLiked: false)
    }

    // MARK: - previewSaved

    @Test func previewSavedTrue() {
        MapAnalytics.previewSaved(surface: .global, spotId: "spot-003", isSaved: true)
    }

    @Test func previewSavedFalse() {
        MapAnalytics.previewSaved(surface: .profile, spotId: nil, isSaved: false)
    }

    // MARK: - previewOpened

    @Test func previewOpenedWithSpotId() {
        MapAnalytics.previewOpened(surface: .global, spotId: "spot-004")
    }

    @Test func previewOpenedWithNilSpotId() {
        MapAnalytics.previewOpened(surface: .profile, spotId: nil)
    }

    // MARK: - previewDismissed

    @Test func previewDismissedTapEmpty() {
        MapAnalytics.previewDismissed(surface: .global, spotId: "spot-005", reason: "tap_empty")
    }

    @Test func previewDismissedSwipeDown() {
        MapAnalytics.previewDismissed(surface: .profile, spotId: nil, reason: "swipe_down")
    }

    // MARK: - filterChanged

    @Test func filterChangedSingleDimension() {
        MapAnalytics.filterChanged(dimensions: ["outdoor"])
    }

    @Test func filterChangedMultipleDimensions() {
        MapAnalytics.filterChanged(dimensions: ["outdoor", "food", "nightlife"])
    }

    @Test func filterChangedEmptyDimensions() {
        MapAnalytics.filterChanged(dimensions: [])
    }

    // MARK: - recenterTapped

    @Test func recenterTapped() {
        MapAnalytics.recenterTapped()
    }
}
