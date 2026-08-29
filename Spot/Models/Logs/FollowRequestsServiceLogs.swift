//
//  FollowRequestsServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FollowRequestsServiceLogs: SpotLog {
    case startCountListener
    case followRequestsCount
    case followRequestAccepted
    case followRequestDenied

    var tag: String { "FollowRequestsService" }
    var level: LogLevel {
        switch self {
        case .startCountListener: return .debug
        case .followRequestsCount: return .info
        case .followRequestAccepted: return .info
        case .followRequestDenied: return .info
        }
    }
    var message: String {
        switch self {
        case .startCountListener: return "Starting follow requests count listener"
        case .followRequestsCount: return "Follow requests count updated"
        case .followRequestAccepted: return "Follow request accepted"
        case .followRequestDenied: return "Follow request denied"
        }
    }
}
