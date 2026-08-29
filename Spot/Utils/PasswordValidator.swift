//
//  PasswordValidator.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Client-side rules aligned with Supabase Auth password guidance (dashboard can enforce too).
enum PasswordValidator {
    static let minimumLength = 8

    enum Result: Equatable {
        case ok
        case failure(String)
    }

    static func validate(_ password: String) -> Result {
        guard password.count >= minimumLength else {
            return .failure("Password must be at least \(minimumLength) characters.")
        }
        guard password.range(of: "[a-z]", options: .regularExpression) != nil else {
            return .failure("Password must include a lowercase letter.")
        }
        guard password.range(of: "[A-Z]", options: .regularExpression) != nil else {
            return .failure("Password must include an uppercase letter.")
        }
        guard password.range(of: "[0-9]", options: .regularExpression) != nil else {
            return .failure("Password must include a digit.")
        }
        guard password.range(of: #"[^\p{L}\p{N}]"#, options: .regularExpression) != nil else {
            return .failure("Password must include a symbol.")
        }
        return .ok
    }
}
