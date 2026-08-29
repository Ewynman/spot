//
//  SpotPermissionType.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import AVFoundation
import CoreLocation
import Foundation
import Photos
import UIKit
import UserNotifications

/// Categories of optional iOS permissions Spot may request. The case order
/// is also the row order shown in Settings → Permissions.
public enum SpotPermissionType: String, CaseIterable, Sendable, Equatable {
    case location
    case notifications
    case camera
    case photos

    /// Display title shown in Settings → Permissions.
    var displayTitle: String {
        switch self {
        case .location: return "Location"
        case .notifications: return "Notifications"
        case .camera: return "Camera"
        case .photos: return "Photos"
        }
    }

    var settingsIcon: String {
        switch self {
        case .location: return "location.circle"
        case .notifications: return "bell"
        case .camera: return "camera"
        case .photos: return "photo.on.rectangle"
        }
    }

    /// Short, neutral explanation used on the Permissions detail screen.
    /// Wording is verified by a static-copy regression test to ensure it
    /// stays App Review-safe (no `Enable...`, no `Required`, etc.).
    var detailExplanation: String {
        switch self {
        case .location:
            return "Location is optional. When it’s off, Spot opens the map over the continental United States instead of centering on you."
        case .notifications:
            return "Notifications are optional. When they’re off, you can still use Spot normally."
        case .camera:
            return "Camera access is optional and is only used when you take a photo for a spot."
        case .photos:
            return "Photo library access is optional and is only used when you choose photos for a spot."
        }
    }
}

/// App-friendly, system-agnostic snapshot of an iOS permission's current
/// authorization. Centralized here so view models and tests don't have to
/// fan out across `CLAuthorizationStatus`, `UNAuthorizationStatus`,
/// `PHAuthorizationStatus`, and `AVAuthorizationStatus`.
public enum SpotPermissionStatus: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
    case unavailable

    /// Whether the row in Settings → Permissions should display the `!`
    /// warning indicator. We do NOT warn on `notDetermined` — the user
    /// hasn't been asked yet, so flagging it would feel coercive.
    var needsAttention: Bool {
        switch self {
        case .denied, .restricted, .unavailable:
            return true
        case .notDetermined, .authorized, .limited:
            return false
        }
    }

    /// Short, neutral status label shown in Settings → Permissions.
    var statusLabel: String {
        switch self {
        case .notDetermined: return "Not Asked"
        case .authorized: return "On"
        case .limited: return "Limited"
        case .denied: return "Off"
        case .restricted: return "Restricted"
        case .unavailable: return "Unavailable"
        }
    }
}

// MARK: - Mappers from system status types

extension SpotPermissionStatus {
    static func map(_ status: CLAuthorizationStatus) -> SpotPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }

    static func map(_ status: UNAuthorizationStatus) -> SpotPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .unavailable
        }
    }

    static func map(_ status: PHAuthorizationStatus) -> SpotPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }

    static func map(_ status: AVAuthorizationStatus) -> SpotPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }
}

// MARK: - AppSettingsOpening

/// Indirection over `UIApplication.shared.open(...)` so views and view
/// models can be unit-tested without launching the iOS Settings app.
public protocol AppSettingsOpening {
    func openAppSettings()
}

public final class UIApplicationSettingsOpener: AppSettingsOpening {
    public static let shared = UIApplicationSettingsOpener()

    public init() {}

    public func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
