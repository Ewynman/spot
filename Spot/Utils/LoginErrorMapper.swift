//
//  LoginErrorMapper.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Maps login failures to user-facing copy without leaking provider noise.
enum LoginErrorMapper {
    static func message(for error: Error) -> String {
        message(forDescription: error.localizedDescription)
    }

    static func message(forDescription description: String) -> String {
        let text = description.lowercased()
        if text.contains("network") || text.contains("internet") {
            return "Network error. Please check your connection."
        }
        if text.contains("email not confirmed") || text.contains("email_not_confirmed") {
            return "Verify your email to finish creating your account."
        }
        if text.contains("enter the email") {
            return "Enter the email address for your account."
        }
        if text.contains("username") || text.contains("no account found") {
            return "No account found for that username."
        }
        return "Incorrect email or password."
    }
}
