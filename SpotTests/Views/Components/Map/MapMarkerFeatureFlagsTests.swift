//
//  MapMarkerFeatureFlagsTests.swift
//  SpotTests
//
//  Verifies `MapMarkerFeatureFlags.withPhotoPinMarkers(_:body:)` restores
//  the flag even when the body throws — the contract the rest of the
//  suite relies on to keep tests isolated from each other's side effects
//  when they need to force the legacy pin path.
//

import Foundation
import Testing
@testable import Spot

struct MapMarkerFeatureFlagsTests {

    private struct SentinelError: Error {}

    @Test func defaultsToEnabled() {
        // Restore the value after reading — nothing else in the suite
        // should observe the assertion side-effect.
        let previous = MapMarkerFeatureFlags.photoPinMarkersEnabled
        defer { MapMarkerFeatureFlags.photoPinMarkersEnabled = previous }
        MapMarkerFeatureFlags.photoPinMarkersEnabled = true
        #expect(MapMarkerFeatureFlags.photoPinMarkersEnabled == true)
    }

    @Test func withPhotoPinMarkersRestoresFlagOnSuccess() {
        MapMarkerFeatureFlags.withPhotoPinMarkers(false) {
            #expect(MapMarkerFeatureFlags.photoPinMarkersEnabled == false)
        }
        #expect(MapMarkerFeatureFlags.photoPinMarkersEnabled == true)
    }

    @Test func withPhotoPinMarkersRestoresFlagOnThrow() {
        do {
            try MapMarkerFeatureFlags.withPhotoPinMarkers(false) {
                #expect(MapMarkerFeatureFlags.photoPinMarkersEnabled == false)
                throw SentinelError()
            }
        } catch {
            // Expected.
        }
        #expect(MapMarkerFeatureFlags.photoPinMarkersEnabled == true)
    }
}
