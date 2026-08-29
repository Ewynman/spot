//
//  ProfileViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum ProfileViewLogs: SpotLog {
    case profileImageLoadFailed
    case openPaywallFromProfileMenu

    var tag: String { "ProfileView" }
    var level: LogLevel {
        switch self {
        case .profileImageLoadFailed: return .error
        case .openPaywallFromProfileMenu: return .info
        }
    }
    var message: String {
        switch self {
        case .profileImageLoadFailed: return "Profile image failed to load"
        case .openPaywallFromProfileMenu: return "Open paywall from profile menu"
        }
    }
}
