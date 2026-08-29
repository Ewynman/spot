//
//  TopNavigationViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum TopNavigationViewLogs: SpotLog {
    case userTappedPostButton

    var tag: String { "TopNavigationView" }
    var level: LogLevel {
        switch self {
        case .userTappedPostButton: return .info
        }
    }
    var message: String {
        switch self {
        case .userTappedPostButton: return "User tapped + button to start post flow"
        }
    }
}
