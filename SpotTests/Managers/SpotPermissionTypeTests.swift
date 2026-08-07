//
//  SpotPermissionTypeTests.swift
//  SpotTests
//
//  Coverage for the App Review-mandated Settings → Permissions surface:
//   * `SpotPermissionStatus.needsAttention` only fires for denied /
//     restricted / unavailable (never for `.notDetermined` or `.limited`).
//   * Status labels stay neutral (no "Required", "Must enable").
//   * System status enums map deterministically into `SpotPermissionStatus`.
//

import AVFoundation
import CoreLocation
import Photos
import Testing
import UserNotifications
@testable import Spot

struct SpotPermissionTypeTests {

    // MARK: - needsAttention semantics

    @Test func deniedNeedsAttention() {
        #expect(SpotPermissionStatus.denied.needsAttention)
    }

    @Test func restrictedNeedsAttention() {
        #expect(SpotPermissionStatus.restricted.needsAttention)
    }

    @Test func unavailableNeedsAttention() {
        #expect(SpotPermissionStatus.unavailable.needsAttention)
    }

    @Test func authorizedDoesNotNeedAttention() {
        #expect(SpotPermissionStatus.authorized.needsAttention == false)
    }

    @Test func limitedDoesNotNeedAttention() {
        // Per PRD §11.2: `.limited` is shown as "Limited" without a warning.
        #expect(SpotPermissionStatus.limited.needsAttention == false)
    }

    @Test func notDeterminedDoesNotNeedAttention() {
        // Per PRD §11.2: `.notDetermined` should not surface a warning —
        // the user simply hasn't been asked yet.
        #expect(SpotPermissionStatus.notDetermined.needsAttention == false)
    }

    // MARK: - Status labels stay App Review-safe

    @Test func statusLabelsAreNeutral() {
        let labels = [
            SpotPermissionStatus.notDetermined.statusLabel,
            SpotPermissionStatus.authorized.statusLabel,
            SpotPermissionStatus.limited.statusLabel,
            SpotPermissionStatus.denied.statusLabel,
            SpotPermissionStatus.restricted.statusLabel,
            SpotPermissionStatus.unavailable.statusLabel
        ]
        for label in labels {
            #expect(!label.localizedCaseInsensitiveContains("Required"))
            #expect(!label.localizedCaseInsensitiveContains("Must enable"))
            #expect(!label.localizedCaseInsensitiveContains("Missing"))
            #expect(!label.localizedCaseInsensitiveContains("Broken"))
        }
        #expect(SpotPermissionStatus.authorized.statusLabel == "On")
        #expect(SpotPermissionStatus.denied.statusLabel == "Off")
        #expect(SpotPermissionStatus.notDetermined.statusLabel == "Not Asked")
        #expect(SpotPermissionStatus.limited.statusLabel == "Limited")
    }

    // MARK: - Detail explanations are App Review-safe

    @Test func detailExplanationsAreNeutral() {
        let forbidden = ["Enable ", "Allow Location", "Allow Notification", "Allow Photo", "Allow Camera",
                         "Maybe Later", "Required", "Must enable", "Turn On"]
        for type in SpotPermissionType.allCases {
            let copy = type.detailExplanation
            for phrase in forbidden {
                #expect(
                    !copy.localizedCaseInsensitiveContains(phrase),
                    "Permission detail copy for \(type) must not contain forbidden phrase: \(phrase)"
                )
            }
        }
    }

    @Test func locationDetailExplainsContinentalUSFallback() {
        let copy = SpotPermissionType.location.detailExplanation
        #expect(copy.localizedCaseInsensitiveContains("United States"))
        #expect(copy.localizedCaseInsensitiveContains("optional"))
    }

    @Test func notificationsDetailExplainsAppStillWorks() {
        let copy = SpotPermissionType.notifications.detailExplanation
        #expect(copy.localizedCaseInsensitiveContains("optional"))
    }

    // MARK: - System status mapping

    @Test func locationStatusMaps() {
        #expect(SpotPermissionStatus.map(CLAuthorizationStatus.notDetermined) == .notDetermined)
        #expect(SpotPermissionStatus.map(CLAuthorizationStatus.authorizedWhenInUse) == .authorized)
        #expect(SpotPermissionStatus.map(CLAuthorizationStatus.authorizedAlways) == .authorized)
        #expect(SpotPermissionStatus.map(CLAuthorizationStatus.denied) == .denied)
        #expect(SpotPermissionStatus.map(CLAuthorizationStatus.restricted) == .restricted)
    }

    @Test func notificationStatusMaps() {
        #expect(SpotPermissionStatus.map(UNAuthorizationStatus.notDetermined) == .notDetermined)
        #expect(SpotPermissionStatus.map(UNAuthorizationStatus.authorized) == .authorized)
        #expect(SpotPermissionStatus.map(UNAuthorizationStatus.denied) == .denied)
        #expect(SpotPermissionStatus.map(UNAuthorizationStatus.provisional) == .authorized)
        #expect(SpotPermissionStatus.map(UNAuthorizationStatus.ephemeral) == .authorized)
    }

    @Test func photoStatusMaps() {
        #expect(SpotPermissionStatus.map(PHAuthorizationStatus.notDetermined) == .notDetermined)
        #expect(SpotPermissionStatus.map(PHAuthorizationStatus.authorized) == .authorized)
        #expect(SpotPermissionStatus.map(PHAuthorizationStatus.limited) == .limited)
        #expect(SpotPermissionStatus.map(PHAuthorizationStatus.denied) == .denied)
        #expect(SpotPermissionStatus.map(PHAuthorizationStatus.restricted) == .restricted)
    }

    @Test func cameraStatusMaps() {
        #expect(SpotPermissionStatus.map(AVAuthorizationStatus.notDetermined) == .notDetermined)
        #expect(SpotPermissionStatus.map(AVAuthorizationStatus.authorized) == .authorized)
        #expect(SpotPermissionStatus.map(AVAuthorizationStatus.denied) == .denied)
        #expect(SpotPermissionStatus.map(AVAuthorizationStatus.restricted) == .restricted)
    }

    // MARK: - Type ordering / display titles

    @Test func displayOrderMatchesPRDPriority() {
        // PRD §11.3 lists rows in this exact order.
        #expect(SpotPermissionType.allCases == [.location, .notifications, .camera, .photos])
    }

    @Test func displayTitlesAreUserFriendly() {
        #expect(SpotPermissionType.location.displayTitle == "Location")
        #expect(SpotPermissionType.notifications.displayTitle == "Notifications")
        #expect(SpotPermissionType.camera.displayTitle == "Camera")
        #expect(SpotPermissionType.photos.displayTitle == "Photos")
    }
}
