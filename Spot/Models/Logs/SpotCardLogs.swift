//
//  SpotCardLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotCardLogs: SpotLog {
    case spotCardAppear
    case ownerGateMissingInputs
    case backButtonTapped
    case imageThumbnailLoadFailed
    case spotImageLoaded
    case imageFullSizeLoadFailed
    case imagePlaceholderUsed
    case menuTapped
    case shareTapped
    case reportTapped
    case userBlocked
    case blockUserFailed
    case deleteTapped
    case invalidMapCoordinate
    case mapPreviewFailed

    var tag: String { "SpotCard" }
    var level: LogLevel {
        switch self {
        case .spotCardAppear: return .debug
        case .ownerGateMissingInputs: return .error
        case .backButtonTapped: return .debug
        case .imageThumbnailLoadFailed: return .error
        case .spotImageLoaded: return .debug
        case .imageFullSizeLoadFailed: return .error
        case .imagePlaceholderUsed: return .debug
        case .menuTapped: return .debug
        case .shareTapped: return .debug
        case .reportTapped: return .debug
        case .userBlocked: return .info
        case .blockUserFailed: return .error
        case .deleteTapped: return .debug
        case .invalidMapCoordinate, .mapPreviewFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .spotCardAppear: return "SpotCard appear"
        case .ownerGateMissingInputs: return "SpotCard owner-gate inputs missing"
        case .backButtonTapped: return "Back button tapped"
        case .imageThumbnailLoadFailed: return "Image thumbnail failed to load"
        case .spotImageLoaded: return "Spot image loaded"
        case .imageFullSizeLoadFailed: return "Image full size failed to load"
        case .imagePlaceholderUsed: return "Image placeholder used"
        case .menuTapped: return "Menu tapped"
        case .shareTapped: return "Share tapped"
        case .reportTapped: return "Report tapped"
        case .userBlocked: return "User blocked"
        case .blockUserFailed: return "Failed to block user"
        case .deleteTapped: return "Delete tapped"
        case .invalidMapCoordinate: return "Home card has invalid map coordinate"
        case .mapPreviewFailed: return "Home card map preview failed"
        }
    }
}
