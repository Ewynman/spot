//
//  MapMarkerLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum MapMarkerLogs: SpotLog, CaseIterable {
    case markersAdded
    case markersRemoved
    case markerReused
    case markerSelected
    case markerDeselected
    case animationBatchStarted
    case animationBatchFinished
    case userMarkerAvatarLoaded
    case userMarkerAvatarFallback
    case userMarkerConfigured
    case userMarkerRemoved
    case userMarkerCustomFailed
    case softClusterShown
    case overlapBucketResolved
    case photoMarkerImageLoaded
    case photoMarkerImageFailed
    case photoMarkerFallbackToTeardrop
    case photoMarkerImpression

    var tag: String { "MapMarker" }
    var level: LogLevel {
        switch self {
        case .markersAdded: return .debug
        case .markersRemoved: return .debug
        case .markerReused: return .debug
        case .markerSelected: return .info
        case .markerDeselected: return .debug
        case .animationBatchStarted: return .debug
        case .animationBatchFinished: return .debug
        case .userMarkerAvatarLoaded: return .debug
        case .userMarkerAvatarFallback: return .debug
        case .userMarkerConfigured: return .debug
        case .userMarkerRemoved: return .debug
        case .userMarkerCustomFailed: return .error
        case .softClusterShown: return .debug
        case .overlapBucketResolved: return .debug
        case .photoMarkerImageLoaded: return .debug
        case .photoMarkerImageFailed: return .debug
        case .photoMarkerFallbackToTeardrop: return .debug
        case .photoMarkerImpression: return .debug
        }
    }
    var message: String {
        switch self {
        case .markersAdded: return "Map markers added"
        case .markersRemoved: return "Map markers removed"
        case .markerReused: return "Map marker view reused"
        case .markerSelected: return "Map marker selected"
        case .markerDeselected: return "Map marker deselected"
        case .animationBatchStarted: return "Map marker animation batch started"
        case .animationBatchFinished: return "Map marker animation batch finished"
        case .userMarkerAvatarLoaded: return "User-location avatar loaded"
        case .userMarkerAvatarFallback: return "User-location avatar fell back to initials/dot"
        case .userMarkerConfigured: return "User-location marker configured"
        case .userMarkerRemoved: return "User-location marker removed (no location fix)"
        case .userMarkerCustomFailed: return "Custom user-location marker failed; using system fallback"
        case .softClusterShown: return "Soft cluster shown at far zoom"
        case .overlapBucketResolved: return "Overlap bucket resolved with radial offsets"
        case .photoMarkerImageLoaded: return "Photo pin thumbnail loaded"
        case .photoMarkerImageFailed: return "Photo pin thumbnail failed"
        case .photoMarkerFallbackToTeardrop: return "Photo pin fell back to teardrop"
        case .photoMarkerImpression: return "Photo pin impression"
        }
    }
}
