//
//  PostFlowViewModelLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum PostFlowViewModelLogs: SpotLog {
    case userWentBack
    case userProgressed
    case userCompletedPostFlow
    case postData

    var tag: String { "PostFlowViewModel" }
    var level: LogLevel {
        switch self {
        case .userWentBack: return .debug
        case .userProgressed: return .debug
        case .userCompletedPostFlow: return .info
        case .postData: return .debug
        }
    }
    var message: String {
        switch self {
        case .userWentBack: return "User went back to previous step"
        case .userProgressed: return "User progressed to next step"
        case .userCompletedPostFlow: return "User completed post flow"
        case .postData: return "Post data summary"
        }
    }
}
