//
//  FeedRepositoryLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FeedRepositoryLogs: SpotLog {
    case loadInitial
    case loadInitialFailed
    case loadMore
    case loadMoreFailed
    case diversityPassApplied
    case feedEnrichFailed

    var tag: String { "FeedRepository" }
    var level: LogLevel {
        switch self {
        case .loadInitial: return .debug
        case .loadInitialFailed: return .error
        case .loadMore: return .debug
        case .loadMoreFailed: return .error
        case .diversityPassApplied: return .info
        case .feedEnrichFailed: return .debug
        }
    }
    var message: String {
        switch self {
        case .loadInitial: return "Feed loadInitial"
        case .loadInitialFailed: return "Feed loadInitial failed"
        case .loadMore: return "Feed loadMore"
        case .loadMoreFailed: return "Feed loadMore failed"
        case .diversityPassApplied: return "Home feed diversity pass applied"
        case .feedEnrichFailed: return "Feed spot enrichment failed"
        }
    }
}
