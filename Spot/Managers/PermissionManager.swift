//
//  PermissionManager.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import Foundation
import CoreLocation
import UserNotifications
import UIKit
import Photos
import AVFoundation

enum LocationPermissionPrimaryAction: Equatable {
    case requestSystemPermission
    case openSettings
    case complete
}

enum LocationPermissionPolicy {
    static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    static func primaryAction(for status: CLAuthorizationStatus) -> LocationPermissionPrimaryAction {
        switch status {
        case .notDetermined:
            return .requestSystemPermission
        case .denied, .restricted:
            return .openSettings
        case .authorizedAlways, .authorizedWhenInUse:
            return .complete
        @unknown default:
            return .complete
        }
    }
}

@MainActor
class PermissionManager: NSObject, ObservableObject {
    static let shared = PermissionManager()
    private let locationManager = CLLocationManager()

    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var photoStatus: PHAuthorizationStatus = .notDetermined
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var showLocationBanner = false
    @Published var showNotificationBanner = false
    @Published private(set) var lifecycleRefreshTick: Int = 0
    private var activeObserver: NSObjectProtocol?

    private override init() {
        super.init()
        locationManager.delegate = self
        startWatchingAppLifecycle()
        updatePermissionStatuses()
    }

    deinit {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
    }

    // MARK: - Permission Status Updates

    func updatePermissionStatuses() {
        locationStatus = locationManager.authorizationStatus
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - App-friendly snapshots (Settings → Permissions)

    /// App-friendly status for a single permission, mapping the underlying
    /// system enum into `SpotPermissionStatus`. Intentionally read-only —
    /// requesting the permission must go through the explicit
    /// `request<Type>Permission()` methods so we never auto-prompt from
    /// Settings.
    func status(for type: SpotPermissionType) -> SpotPermissionStatus {
        switch type {
        case .location: return SpotPermissionStatus.map(locationStatus)
        case .notifications: return SpotPermissionStatus.map(notificationStatus)
        case .camera: return SpotPermissionStatus.map(cameraStatus)
        case .photos: return SpotPermissionStatus.map(photoStatus)
        }
    }

    /// Returns true when at least one of the four optional permissions is
    /// in a state that needs user attention (denied/restricted/unavailable).
    /// Powers the `!` warning indicator on the Settings → Permissions row.
    var anyPermissionNeedsAttention: Bool {
        SpotPermissionType.allCases.contains { status(for: $0).needsAttention }
    }

    private func startWatchingAppLifecycle() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updatePermissionStatuses()
                self.lifecycleRefreshTick += 1
            }
        }
    }

    // MARK: - Post-Login Permission Requests

    /// Deprecated bulk-request entry point. Each permission is now requested
    /// from its own dedicated onboarding step (or contextual prompt) so the
    /// user always sees the matching pre-prompt before the native dialog.
    /// Kept as a no-op for source compatibility with older call sites.
    func requestPermissionsIfNeeded() {
        // Intentionally empty.
    }

    // MARK: - Explicit Requests (for onboarding buttons)
    func requestLocationPermission() {
        updatePermissionStatuses()
        if locationStatus == .notDetermined {
            SpotLogger.log(PermissionManagerLogs.locationPermissionRequestedExplicit)
            Task { @MainActor in
                AnalyticsService.shared.trackPermissionRequest(type: "location", action: "explicit")
            }
            locationManager.requestWhenInUseAuthorization()
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.locationPermissionRequested)
        } else if locationStatus == .denied || locationStatus == .restricted {
            showLocationBanner = true
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                self.notificationStatus = status
                switch status {
                case .notDetermined:
                    SpotLogger.log(PermissionManagerLogs.pushPermissionRequestedExplicit)
                    Task { @MainActor in
                        AnalyticsService.shared.trackPermissionRequest(type: "push", action: "explicit")
                    }
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted {
                                SpotLogger.log(PermissionManagerLogs.pushPermissionGranted)
                                Task { @MainActor in
                                    AnalyticsService.shared.trackPermissionRequest(type: "push", action: "explicit", result: "granted")
                                }
                            } else {
                                SpotLogger.log(PermissionManagerLogs.pushPermissionDenied)
                                Task { @MainActor in
                                    AnalyticsService.shared.trackPermissionRequest(type: "push", action: "explicit", result: "denied")
                                }
                                self.showNotificationBanner = true
                            }
                            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.notificationsRequested)
                            self.updatePermissionStatuses()
                        }
                    }
                case .denied, .provisional, .ephemeral:
                    self.showNotificationBanner = true
                case .authorized:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    func requestPhotoPermission() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoStatus = currentStatus
        guard currentStatus == .notDetermined else { return }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                self.photoStatus = newStatus
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.photoPermissionRequested)
            }
        }
    }

    func requestCameraPermission() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = currentStatus
        guard currentStatus == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async {
                self.cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.cameraPermissionRequested)
            }
        }
    }

    // MARK: - Banner Actions

    func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    func openPhotoSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    func openCameraSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    func dismissLocationBanner() {
        showLocationBanner = false
    }

    func dismissNotificationBanner() {
        showNotificationBanner = false
    }

    /// Core Location calls the delegate off the main actor; keep updates on `@MainActor` here.
    private func applyLocationAuthorizationChange(_ newStatus: CLAuthorizationStatus) {
        locationStatus = newStatus

        switch newStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            SpotLogger.log(PermissionManagerLogs.locationPermissionGranted)
            Task { @MainActor in
                AnalyticsService.shared.trackPermissionRequest(type: "location", action: "system_change", result: "granted")
            }
            showLocationBanner = false
        case .denied, .restricted:
            SpotLogger.log(PermissionManagerLogs.locationPermissionDenied)
            Task { @MainActor in
                AnalyticsService.shared.trackPermissionRequest(type: "location", action: "system_change", result: "denied")
            }
            showLocationBanner = true
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.applyLocationAuthorizationChange(newStatus)
        }
    }
}
