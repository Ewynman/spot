//
//  ProfileViewModelLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum ProfileViewModelLogs: SpotLog {
    case profileLoaded
    case loadUserFailed
    case profileDeleteFailed
    case followStateRefreshAfterMutation

    var tag: String { "ProfileViewModel" }
    var level: LogLevel {
        switch self {
        case .profileLoaded: return .info
        case .loadUserFailed: return .error
        case .profileDeleteFailed: return .error
        case .followStateRefreshAfterMutation: return .info
        }
    }
    var message: String {
        switch self {
        case .profileLoaded: return "Loaded profile for user"
        case .loadUserFailed: return "Profile loadUser failed"
        case .profileDeleteFailed: return "Profile delete failed"
        case .followStateRefreshAfterMutation: return "Refreshing profile after follow graph mutation"
        }
    }
}
