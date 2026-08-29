//
//  SearchDataSourceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SearchDataSourceLogs: SpotLog {
    case locationSuggestions
    case vibeSuggestions

    var tag: String { "SpotSearchDataSource" }
    var level: LogLevel {
        switch self {
        case .locationSuggestions: return .debug
        case .vibeSuggestions: return .debug
        }
    }
    var message: String {
        switch self {
        case .locationSuggestions: return "Location suggestions"
        case .vibeSuggestions: return "Vibe suggestions"
        }
    }
}
