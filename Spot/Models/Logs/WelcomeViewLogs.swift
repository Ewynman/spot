//
//  WelcomeViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum WelcomeViewLogs: SpotLog {
    case screenViewed
    case appleSignInTapped
    case appleSignInSucceeded
    case appleSignInFailed
    case getStartedTapped
    case loginTapped
    case navigationSucceeded

    var tag: String { "WelcomeView" }

    var level: LogLevel {
        switch self {
        case .appleSignInFailed:
            return .error
        case .screenViewed, .appleSignInTapped, .appleSignInSucceeded, .getStartedTapped, .loginTapped, .navigationSucceeded:
            return .info
        }
    }

    var message: String {
        switch self {
        case .screenViewed: return "Welcome screen viewed"
        case .appleSignInTapped: return "Welcome Apple sign-in tapped"
        case .appleSignInSucceeded: return "Welcome Apple sign-in succeeded"
        case .appleSignInFailed: return "Welcome Apple sign-in failed"
        case .getStartedTapped: return "Welcome get started tapped"
        case .loginTapped: return "Welcome log in tapped"
        case .navigationSucceeded: return "Welcome navigation succeeded"
        }
    }
}
