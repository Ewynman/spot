//
//  FollowRequestsViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FollowRequestsViewLogs: SpotLog {
    case followRequestsOpened
    case refreshFailed
    case loadMoreFailed
    case acceptFailed
    case denyFailed

    var tag: String { "FollowRequestsView" }
    var level: LogLevel {
        switch self {
        case .followRequestsOpened: return .info
        case .refreshFailed: return .error
        case .loadMoreFailed: return .error
        case .acceptFailed: return .error
        case .denyFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .followRequestsOpened: return "Follow requests opened"
        case .refreshFailed: return "FollowRequestsView refresh failed"
        case .loadMoreFailed: return "FollowRequestsView loadMore failed"
        case .acceptFailed: return "Accept follow request failed"
        case .denyFailed: return "Deny follow request failed"
        }
    }
}
