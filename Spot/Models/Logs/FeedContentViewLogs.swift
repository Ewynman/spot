//
//  FeedContentViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FeedContentViewLogs: SpotLog {
    case missingImageUrl

    var tag: String { "FeedContentView" }
    var level: LogLevel {
        switch self {
        case .missingImageUrl: return .error
        }
    }
    var message: String {
        switch self {
        case .missingImageUrl: return "Feed missing imageURL for spot"
        }
    }
}
