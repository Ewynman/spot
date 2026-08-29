//
//  SpotGridScreenLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotGridScreenLogs: SpotLog {
    case headerBackClearsInlineSpot
    case backButtonTapped
    case openSpotFromGrid
    case onAppear
    case loadData
    case dataLoaded

    var tag: String { "SpotGridScreen" }
    var level: LogLevel {
        switch self {
        case .headerBackClearsInlineSpot: return .debug
        case .backButtonTapped: return .debug
        case .openSpotFromGrid: return .debug
        case .onAppear: return .debug
        case .loadData: return .debug
        case .dataLoaded: return .debug
        }
    }
    var message: String {
        switch self {
        case .headerBackClearsInlineSpot: return "Header back clears inline spot"
        case .backButtonTapped: return "Back button tapped - dismiss"
        case .openSpotFromGrid: return "Open spot from grid"
        case .onAppear: return "SpotGridScreen onAppear"
        case .loadData: return "SpotGridScreen load data"
        case .dataLoaded: return "SpotGridScreen data loaded"
        }
    }
}
