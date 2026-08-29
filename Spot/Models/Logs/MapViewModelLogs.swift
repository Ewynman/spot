//
//  MapViewModelLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum MapViewModelLogs: SpotLog {
    case mapLoadedAllSpots
    case loadAllSpotsFailed
    case viewportFetchStarted
    case viewportFetchFinished
    case viewportFetchCancelled
    case visibleSpotsMerged
    case visibleSpotsTrimmed

    var tag: String { "MapViewModel" }
    var level: LogLevel {
        switch self {
        case .mapLoadedAllSpots: return .info
        case .loadAllSpotsFailed: return .error
        case .viewportFetchStarted: return .debug
        case .viewportFetchFinished: return .debug
        case .viewportFetchCancelled: return .debug
        case .visibleSpotsMerged: return .debug
        case .visibleSpotsTrimmed: return .debug
        }
    }
    var message: String {
        switch self {
        case .mapLoadedAllSpots: return "Map loaded all spots"
        case .loadAllSpotsFailed: return "Failed to load all spots for map"
        case .viewportFetchStarted: return "Viewport fetch started"
        case .viewportFetchFinished: return "Viewport fetch finished"
        case .viewportFetchCancelled: return "Viewport fetch cancelled"
        case .visibleSpotsMerged: return "Visible spots merged from viewport result"
        case .visibleSpotsTrimmed: return "Visible spots trimmed to cap"
        }
    }
}
