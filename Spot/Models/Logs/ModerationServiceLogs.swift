//
//  ModerationServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum ModerationServiceLogs: SpotLog {
    case spotReportSubmitted
    case spotReportFailed
    case profileReportSubmitted
    case profileReportFailed
    case userBlocked
    case userBlockFailed
    case userUnblocked
    case userUnblockFailed
    case rpcRpcMissingArguments

    var tag: String { "ModerationService" }
    var level: LogLevel {
        switch self {
        case .spotReportSubmitted, .profileReportSubmitted, .userBlocked, .userUnblocked:
            return .info
        case .rpcRpcMissingArguments:
            return .error
        case .spotReportFailed, .profileReportFailed, .userBlockFailed, .userUnblockFailed:
            return .error
        }
    }
    var message: String {
        switch self {
        case .spotReportSubmitted: return "Spot report submitted via submit_content_report RPC"
        case .spotReportFailed: return "Spot report failed via submit_content_report RPC"
        case .profileReportSubmitted: return "Profile report submitted via submit_content_report RPC"
        case .profileReportFailed: return "Profile report failed via submit_content_report RPC"
        case .userBlocked: return "User blocked via block_user_v1 RPC"
        case .userBlockFailed: return "User block failed via block_user_v1 RPC"
        case .userUnblocked: return "User unblocked"
        case .userUnblockFailed: return "User unblock failed"
        case .rpcRpcMissingArguments: return "ModerationService RPC missing required arguments"
        }
    }
}
