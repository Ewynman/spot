//
//  VerificationEmailMask.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Masks an email for verification UI (e.g. `ed****@example.com`).
enum VerificationEmailMask {
    static func mask(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return email }
        let name = email[..<at]
        let domain = email[at...]
        let keep = min(2, name.count)
        let head = name.prefix(keep)
        return String(head) + "****" + String(domain)
    }
}
