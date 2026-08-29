//
//  LocationManagerLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum LocationManagerLogs: SpotLog, CaseIterable {
    case locationUpdateFailed
    case locationFixReceived
    case authorizationChanged
    case authorizationRequested
    case oneShotLocationRequested
    case startUpdatingLocation
    case stopUpdatingLocation
    case simulatorOverrideApplied
    case managerInitialized
    case offMainThreadInitialization
    case pendingOneShotDrained

    var tag: String { "LocationManager" }
    var level: LogLevel {
        switch self {
        case .locationUpdateFailed, .offMainThreadInitialization: return .error
        case .authorizationChanged, .authorizationRequested,
             .oneShotLocationRequested, .startUpdatingLocation, .stopUpdatingLocation,
             .simulatorOverrideApplied, .managerInitialized:
            return .info
        case .locationFixReceived, .pendingOneShotDrained: return .debug
        }
    }
    var message: String {
        switch self {
        case .locationUpdateFailed: return "Location update failed"
        case .locationFixReceived: return "Received location fix"
        case .authorizationChanged: return "Location authorization changed"
        case .authorizationRequested: return "Requested location authorization"
        case .oneShotLocationRequested: return "Requested one-shot location fix"
        case .startUpdatingLocation: return "startUpdatingLocation called"
        case .stopUpdatingLocation: return "stopUpdatingLocation called"
        case .simulatorOverrideApplied: return "Simulator location override applied"
        case .managerInitialized: return "LocationManager initialized"
        case .offMainThreadInitialization:
            return "LocationManager built CLLocationManager off the main thread; delegate callbacks will never fire"
        case .pendingOneShotDrained: return "Drained pending one-shot location request after authorization"
        }
    }
}
