//
//  VibeTagServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum VibeTagServiceLogs: SpotLog {
    case vibeTagSaved
    case savingVibeTagFailed
    case fetchVibeTagsFailed

    var tag: String { "VibeTagService" }
    var level: LogLevel {
        switch self {
        case .vibeTagSaved: return .info
        case .savingVibeTagFailed: return .error
        case .fetchVibeTagsFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .vibeTagSaved: return "VibeTag saved"
        case .savingVibeTagFailed: return "Failed saving vibe tag"
        case .fetchVibeTagsFailed: return "Failed to fetch vibe tags"
        }
    }
}
