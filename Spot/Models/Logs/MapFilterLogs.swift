//
//  MapFilterLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum MapFilterLogs: SpotLog {
    case filterSheetOpened
    case filterApplied
    case filterCleared
    case filterGatedTapped
    case filterMatchHighlighted

    var tag: String { "MapFilter" }
    var level: LogLevel {
        switch self {
        case .filterSheetOpened: return .info
        case .filterApplied: return .info
        case .filterCleared: return .info
        case .filterGatedTapped: return .info
        case .filterMatchHighlighted: return .debug
        }
    }
    var message: String {
        switch self {
        case .filterSheetOpened: return "Map filter sheet opened"
        case .filterApplied: return "Map filter applied"
        case .filterCleared: return "Map filter cleared"
        case .filterGatedTapped: return "Map filter gated for non-Pro user"
        case .filterMatchHighlighted: return "Map filter match highlighted"
        }
    }
}
