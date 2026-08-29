//
//  VibeTagUsageStoreLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum VibeTagUsageStoreLogs: SpotLog {
    case noTagsToRecord
    case usageDecodeFailed
    case usageEncodeFailed
    case usageRecorded

    var tag: String { "VibeTagUsageStore" }

    var level: LogLevel {
        switch self {
        case .noTagsToRecord:
            return .debug
        case .usageRecorded:
            return .info
        case .usageDecodeFailed, .usageEncodeFailed:
            return .error
        }
    }

    var message: String {
        switch self {
        case .noTagsToRecord:
            return "Skipped usage update: no tags to record"
        case .usageDecodeFailed:
            return "Failed to decode vibe usage payload from UserDefaults"
        case .usageEncodeFailed:
            return "Failed to encode vibe usage payload to UserDefaults"
        case .usageRecorded:
            return "Recorded vibe usage"
        }
    }
}
