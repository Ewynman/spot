//
//  AuthProfileSetupGate.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Auth
import Foundation
import Supabase

enum AuthProfileSetupGate {
    /// True when the user signed in with Apple (or has an Apple identity linked).
    static func shouldShowUsernamePhotoPostAuthSetup(session: Session) -> Bool {
        if let identities = session.user.identities {
            for identity in identities where identity.provider.lowercased() == "apple" {
                return true
            }
        }
        if let raw = session.user.appMetadata["provider"]?.stringValue?.lowercased(), raw == "apple" {
            return true
        }
        return false
    }
}
