//
//  BookmarksViewModelLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum BookmarksViewModelLogs: SpotLog {
    case loadedSpots
    case loadInitialFailed

    var tag: String { "BookmarksViewModel" }
    var level: LogLevel {
        switch self {
        case .loadedSpots: return .info
        case .loadInitialFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .loadedSpots: return "Loaded spots for bookmarks"
        case .loadInitialFailed: return "BookmarksViewModel loadInitial failed"
        }
    }
}
