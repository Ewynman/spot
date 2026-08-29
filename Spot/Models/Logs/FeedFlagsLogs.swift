//
//  FeedFlagsLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FeedFlagsLogs: SpotLog {
    case feedExclusion
    case feedStats
    case feedColdStart

    var tag: String { "FeedFlags" }
    var level: LogLevel {
        switch self {
        case .feedExclusion: return .debug
        case .feedStats: return .debug
        case .feedColdStart: return .debug
        }
    }
    var message: String {
        switch self {
        case .feedExclusion: return "Feed exclusion"
        case .feedStats: return "Feed stats"
        case .feedColdStart: return "Feed cold start"
        }
    }
}
