//
//  FeedViewModelLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FeedViewModelLogs: SpotLog {
    case insertedNewSpotAtTop
    case mapSpotsWarmDisabled
    case deleteRequestedWithoutId
    case deleteInvalidSpotId
    case deletingSpot
    case deleteFailed

    var tag: String { "FeedViewModel" }
    var level: LogLevel {
        switch self {
        case .insertedNewSpotAtTop: return .info
        case .mapSpotsWarmDisabled: return .debug
        case .deleteRequestedWithoutId: return .error
        case .deleteInvalidSpotId: return .error
        case .deletingSpot: return .info
        case .deleteFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .insertedNewSpotAtTop: return "Inserted new spot at top of feed"
        case .mapSpotsWarmDisabled: return "Map spots warm disabled; viewport loader handles fetching"
        case .deleteRequestedWithoutId: return "Delete requested for spot without ID"
        case .deleteInvalidSpotId: return "Delete requested with invalid spot UUID"
        case .deletingSpot: return "Deleting spot"
        case .deleteFailed: return "Delete failed"
        }
    }
}
