//
//  TabNavigationViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum TabNavigationViewLogs: SpotLog {
    case userSwitchedTab
    case userTappedPostButton

    var tag: String { "TabNavigationView" }
    var level: LogLevel {
        switch self {
        case .userSwitchedTab: return .debug
        case .userTappedPostButton: return .info
        }
    }
    var message: String {
        switch self {
        case .userSwitchedTab: return "User switched to tab"
        case .userTappedPostButton: return "User tapped + button to start post flow"
        }
    }
}
