//
//  AppDelegateLogs.swift
//  Spot
//
//  Log definitions for AppDelegate.
//

import Foundation

enum AppDelegateLogs: SpotLog {
    case universalLinkOnLaunch
    case customSchemeUrlOnLaunch
    case locationUpdateFailed
    case memoryWarning
    case notificationActionReceived
    case firebaseConfigurationMissing

    var tag: String { "AppDelegate" }
    var level: LogLevel {
        switch self {
        case .universalLinkOnLaunch: return .info
        case .customSchemeUrlOnLaunch: return .info
        case .locationUpdateFailed: return .error
        case .memoryWarning: return .info
        case .notificationActionReceived: return .info
        case .firebaseConfigurationMissing: return .error
        }
    }
    var message: String {
        switch self {
        case .universalLinkOnLaunch: return "Received Universal Link on app launch"
        case .customSchemeUrlOnLaunch: return "Received custom scheme URL on app launch"
        case .locationUpdateFailed: return "Location update failed"
        case .memoryWarning: return "Received memory warning; cleared in-memory caches"
        case .notificationActionReceived: return "User tapped notification action"
        case .firebaseConfigurationMissing: return "GoogleService-Info.plist missing; Firebase initialization skipped"
        }
    }
}
