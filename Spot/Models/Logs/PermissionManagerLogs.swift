//
//  PermissionManagerLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum PermissionManagerLogs: SpotLog {
    case locationPermissionRequestedExplicit
    case pushPermissionRequestedExplicit
    case pushPermissionGranted
    case pushPermissionDenied
    case locationPermissionRequesting
    case pushPermissionRequesting
    case locationPermissionGranted
    case locationPermissionDenied

    var tag: String { "PermissionManager" }
    var level: LogLevel {
        switch self {
        case .locationPermissionRequestedExplicit: return .info
        case .pushPermissionRequestedExplicit: return .info
        case .pushPermissionGranted: return .info
        case .pushPermissionDenied: return .info
        case .locationPermissionRequesting: return .info
        case .pushPermissionRequesting: return .info
        case .locationPermissionGranted: return .info
        case .locationPermissionDenied: return .info
        }
    }
    var message: String {
        switch self {
        case .locationPermissionRequestedExplicit: return "Location permission requested explicitly"
        case .pushPermissionRequestedExplicit: return "Push permission requested explicitly"
        case .pushPermissionGranted: return "Push permission granted"
        case .pushPermissionDenied: return "Push permission denied"
        case .locationPermissionRequesting: return "Location permission auto-requesting"
        case .pushPermissionRequesting: return "Push permission auto-requesting"
        case .locationPermissionGranted: return "Location permission granted"
        case .locationPermissionDenied: return "Location permission denied"
        }
    }
}
