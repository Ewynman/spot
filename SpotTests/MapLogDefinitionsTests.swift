//
//  MapLogDefinitionsTests.swift
//  SpotTests
//
//

import Foundation
import Testing
@testable import Spot

struct MapLogDefinitionsTests {

    // MARK: - Shared invariants

    @Test func locationManagerLogsHaveCompleteDefinitions() {
        for entry in LocationManagerLogs.allCases {
            #expect(entry.tag == "LocationManager")
            #expect(!entry.message.isEmpty)
        }
    }

    @Test func mapViewLogsHaveCompleteDefinitions() {
        for entry in MapViewLogs.allCases {
            #expect(entry.tag == "MapView")
            #expect(!entry.message.isEmpty)
        }
    }

    @Test func mapMarkerLogsHaveCompleteDefinitions() {
        for entry in MapMarkerLogs.allCases {
            #expect(entry.tag == "MapMarker")
            #expect(!entry.message.isEmpty)
        }
    }

    @Test func mapLogMessagesAreUniqueWithinEachTag() {
        #expect(Set(LocationManagerLogs.allCases.map(\.message)).count == LocationManagerLogs.allCases.count)
        #expect(Set(MapViewLogs.allCases.map(\.message)).count == MapViewLogs.allCases.count)
        #expect(Set(MapMarkerLogs.allCases.map(\.message)).count == MapMarkerLogs.allCases.count)
    }

    // MARK: - Severity

    /// A failure the user can feel must not be filtered out at the default
    /// logging profile, so these two stay at `.error`.
    @Test func locationFailuresAreErrorLevel() {
        #expect(LocationManagerLogs.locationUpdateFailed.level == .error)
        #expect(LocationManagerLogs.offMainThreadInitialization.level == .error)
    }

    /// `CLLocationManager` built off a run-loop thread never calls its delegate,
    /// which silently breaks the map. The tripwire message has to name the
    /// consequence so it is actionable without reading this file.
    @Test func offMainThreadInitializationExplainsTheConsequence() {
        let message = LocationManagerLogs.offMainThreadInitialization.message
        #expect(message.contains("main thread"))
        #expect(message.contains("delegate"))
    }

    @Test func routineLocationLifecycleIsInfoLevel() {
        #expect(LocationManagerLogs.managerInitialized.level == .info)
        #expect(LocationManagerLogs.authorizationChanged.level == .info)
        #expect(LocationManagerLogs.authorizationRequested.level == .info)
        #expect(LocationManagerLogs.oneShotLocationRequested.level == .info)
        #expect(LocationManagerLogs.startUpdatingLocation.level == .info)
        #expect(LocationManagerLogs.stopUpdatingLocation.level == .info)
        #expect(LocationManagerLogs.simulatorOverrideApplied.level == .info)
    }

    /// High-frequency events must stay at `.debug` so they cannot flood the
    /// default profile.
    @Test func highFrequencyLocationEventsAreDebugLevel() {
        #expect(LocationManagerLogs.locationFixReceived.level == .debug)
        #expect(LocationManagerLogs.pendingOneShotDrained.level == .debug)
    }

    @Test func mapScreenLifecycleIsInfoLevel() {
        #expect(MapViewLogs.mapAppeared.level == .info)
        #expect(MapViewLogs.mapDisappeared.level == .info)
        #expect(MapViewLogs.recenterTapped.level == .info)
        #expect(MapViewLogs.userLocationUnavailable.level == .info)
    }

    /// Camera intents fire on every pan and settle, so they must never be
    /// promoted above `.debug`.
    @Test func cameraIntentEventsAreDebugLevel() {
        #expect(MapViewLogs.cameraIntentApplied.level == .debug)
        #expect(MapViewLogs.cameraIntentSkippedDuplicate.level == .debug)
        #expect(MapViewLogs.staleCameraIntentCleared.level == .debug)
    }

    @Test func markerRenderingEventsAreDebugExceptSelectionAndFailure() {
        #expect(MapMarkerLogs.markersAdded.level == .debug)
        #expect(MapMarkerLogs.userMarkerRemoved.level == .debug)
        #expect(MapMarkerLogs.userMarkerConfigured.level == .debug)
        #expect(MapMarkerLogs.markerSelected.level == .info)
        #expect(MapMarkerLogs.userMarkerCustomFailed.level == .error)
    }
}
