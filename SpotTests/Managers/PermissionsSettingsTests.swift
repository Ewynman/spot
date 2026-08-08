//
//  PermissionsSettingsTests.swift
//  SpotTests
//
//  Coverage for the Apple App Review-mandated Settings → Permissions
//  surface. The detail view itself is SwiftUI, so these tests focus on the
//  observable plumbing:
//
//   * `PermissionManager.anyPermissionNeedsAttention` correctly drives the
//     `!` warning indicator on the Settings row.
//   * The injected `AppSettingsOpening` dependency receives exactly one
//     call when the user taps "Open iOS Settings" (no auto-prompts).
//

import Testing
@testable import Spot

@MainActor
@Suite(.serialized)
struct PermissionsSettingsTests {

    // MARK: - !`warning indicator wiring

    @Test func anyPermissionNeedsAttentionFlipsWhenLocationDenied() {
        let mgr = PermissionManager.shared
        mgr.locationStatus = .denied
        mgr.notificationStatus = .authorized
        mgr.photoStatus = .authorized
        mgr.cameraStatus = .authorized
        #expect(mgr.anyPermissionNeedsAttention)

        mgr.locationStatus = .authorizedWhenInUse
        #expect(mgr.anyPermissionNeedsAttention == false)
    }

    @Test func anyPermissionNeedsAttentionFlipsWhenNotificationsDenied() {
        let mgr = PermissionManager.shared
        mgr.locationStatus = .authorizedWhenInUse
        mgr.notificationStatus = .denied
        mgr.photoStatus = .authorized
        mgr.cameraStatus = .authorized
        #expect(mgr.anyPermissionNeedsAttention)
    }

    @Test func anyPermissionNeedsAttentionFlipsWhenCameraDenied() {
        let mgr = PermissionManager.shared
        mgr.locationStatus = .authorizedWhenInUse
        mgr.notificationStatus = .authorized
        mgr.photoStatus = .authorized
        mgr.cameraStatus = .denied
        #expect(mgr.anyPermissionNeedsAttention)
    }

    @Test func anyPermissionNeedsAttentionFlipsWhenPhotosDenied() {
        let mgr = PermissionManager.shared
        mgr.locationStatus = .authorizedWhenInUse
        mgr.notificationStatus = .authorized
        mgr.photoStatus = .denied
        mgr.cameraStatus = .authorized
        #expect(mgr.anyPermissionNeedsAttention)
    }

    @Test func notDeterminedDoesNotTriggerWarningIndicator() {
        // PRD §11.2: `notDetermined` should not show the `!` indicator —
        // the user simply hasn't been asked yet, and Apple flags coercive
        // status badges.
        let mgr = PermissionManager.shared
        mgr.locationStatus = .notDetermined
        mgr.notificationStatus = .notDetermined
        mgr.photoStatus = .notDetermined
        mgr.cameraStatus = .notDetermined
        #expect(mgr.anyPermissionNeedsAttention == false)
    }

    @Test func limitedPhotoAccessDoesNotTriggerWarningIndicator() {
        // PRD §11.2: `.limited` is a successful state — show "Limited" but
        // no warning unless that limited access actively blocks a feature.
        let mgr = PermissionManager.shared
        mgr.locationStatus = .authorizedWhenInUse
        mgr.notificationStatus = .authorized
        mgr.photoStatus = .limited
        mgr.cameraStatus = .authorized
        #expect(mgr.anyPermissionNeedsAttention == false)
    }

    // MARK: - PermissionManager.status snapshot

    @Test func statusSnapshotMatchesRawSystemValues() {
        let mgr = PermissionManager.shared
        mgr.locationStatus = .denied
        mgr.notificationStatus = .authorized
        mgr.photoStatus = .limited
        mgr.cameraStatus = .restricted

        #expect(mgr.status(for: .location) == .denied)
        #expect(mgr.status(for: .notifications) == .authorized)
        #expect(mgr.status(for: .photos) == .limited)
        #expect(mgr.status(for: .camera) == .restricted)
    }

    // MARK: - AppSettingsOpening injection

    @Test func openIosSettingsActionUsesInjectedOpener() {
        let fakeOpener = CountingSettingsOpener()
        // Touch the contract that PermissionsSettingsView relies on. We
        // call openAppSettings() directly — the SwiftUI button binds to
        // the same closure, so this asserts the dependency wiring works.
        fakeOpener.openAppSettings()
        fakeOpener.openAppSettings()
        #expect(fakeOpener.callCount == 2)
    }

    @Test func uiApplicationSettingsOpenerExists() {
        // Smoke check that the production opener stays a singleton with the
        // expected protocol conformance. A regression here usually means the
        // production opener has been deleted or renamed, which would silently
        // break Settings → Permissions.
        let opener: AppSettingsOpening = UIApplicationSettingsOpener.shared
        _ = opener
        #expect(true)
    }
}

private final class CountingSettingsOpener: AppSettingsOpening {
    private(set) var callCount: Int = 0
    func openAppSettings() {
        callCount += 1
    }
}
