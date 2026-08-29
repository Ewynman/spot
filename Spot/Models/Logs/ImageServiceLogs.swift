//
//  ImageServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum ImageServiceLogs: SpotLog {
    case skippingPreviouslyFailedUrl
    case invalidOrNonHttpsUrl
    case imageLoadedSuccessfully
    case imageLoadFailed
    case imageLoadFailedAnalytics
    case gsUrlConversionNeeded

    var tag: String { "ImageService" }
    var level: LogLevel {
        switch self {
        case .skippingPreviouslyFailedUrl: return .debug
        case .invalidOrNonHttpsUrl: return .error
        case .imageLoadedSuccessfully: return .debug
        case .imageLoadFailed: return .debug
        case .imageLoadFailedAnalytics: return .error
        case .gsUrlConversionNeeded: return .debug
        }
    }
    var message: String {
        switch self {
        case .skippingPreviouslyFailedUrl: return "Skipping previously failed URL"
        case .invalidOrNonHttpsUrl: return "Invalid or non-HTTPS URL"
        case .imageLoadedSuccessfully: return "Successfully loaded image"
        case .imageLoadFailed: return "Image load failed"
        case .imageLoadFailedAnalytics: return "Image load failed (analytics threshold)"
        case .gsUrlConversionNeeded: return "GS URL conversion needed"
        }
    }
}
