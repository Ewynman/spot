//
//  LoginViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum LoginViewLogs: SpotLog {
    case passwordResetRequested
    case passwordResetError
    case loginSuccess
    case loginFailed

    var tag: String { "LoginView" }
    var level: LogLevel {
        switch self {
        case .passwordResetRequested: return .info
        case .passwordResetError: return .error
        case .loginSuccess: return .info
        case .loginFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .passwordResetRequested: return "Password reset requested"
        case .passwordResetError: return "Password reset error"
        case .loginSuccess: return "User logged in successfully"
        case .loginFailed: return "Login failed"
        }
    }
}
