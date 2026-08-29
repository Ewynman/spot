//
//  FreshInstallDetectorLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FreshInstallDetectorLogs: SpotLog {
    case reinstallWithKeychainUser
    case reinstallWithoutKeychainUser
    case resetInstallScopedCaches

    var tag: String { "FreshInstallDetector" }
    var level: LogLevel {
        switch self {
        case .reinstallWithKeychainUser: return .info
        case .reinstallWithoutKeychainUser: return .info
        case .resetInstallScopedCaches: return .info
        }
    }
    var message: String {
        switch self {
        case .reinstallWithKeychainUser: return "Reinstall detected with keychain user: retained local session"
        case .reinstallWithoutKeychainUser: return "Reinstall without keychain user: no action needed"
        case .resetInstallScopedCaches: return "Reset install-scoped caches without clearing authentication"
        }
    }
}
