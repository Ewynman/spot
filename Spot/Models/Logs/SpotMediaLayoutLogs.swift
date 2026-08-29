//
//  SpotMediaLayoutLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotMediaLayoutLogs: SpotLog {
    case fallbackDisplayRatio
    case clampedStoredRatio
    case carouselLayout
    case jpegDimensionsRead
    case displayRatioCalculated
    case mediaAssetDimensionsAttached

    var tag: String { "SpotMedia" }

    var level: LogLevel {
        switch self {
        case .fallbackDisplayRatio: return .debug
        case .clampedStoredRatio: return .debug
        case .carouselLayout: return .debug
        case .jpegDimensionsRead: return .debug
        case .displayRatioCalculated: return .debug
        case .mediaAssetDimensionsAttached: return .debug
        }
    }

    var message: String {
        switch self {
        case .fallbackDisplayRatio: return "Spot media using fallback display aspect ratio"
        case .clampedStoredRatio: return "Clamped stored media_display_aspect_ratio for render"
        case .carouselLayout: return "Spot image carousel laid out"
        case .jpegDimensionsRead: return "Read JPEG pixel dimensions for upload metadata"
        case .displayRatioCalculated: return "Calculated display aspect ratio from pixels"
        case .mediaAssetDimensionsAttached: return "Attached width/height to media_assets insert"
        }
    }
}
