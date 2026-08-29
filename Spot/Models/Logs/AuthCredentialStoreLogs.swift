//
//  AuthCredentialStoreLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum AuthCredentialStoreLogs: SpotLog {
    case saveFailed
    case loadFailed
    case deleteFailed

    var tag: String { "AuthCredentialStore" }
    var level: LogLevel { .error }

    var message: String {
        switch self {
        case .saveFailed: return "Failed to save authentication recovery data"
        case .loadFailed: return "Failed to load authentication recovery data"
        case .deleteFailed: return "Failed to delete authentication recovery data"
        }
    }
}
