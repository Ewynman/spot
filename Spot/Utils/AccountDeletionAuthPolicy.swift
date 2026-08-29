//
//  AccountDeletionAuthPolicy.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Auth
import Foundation
import Supabase

enum AccountDeletionReauthMethod: Equatable {
    case password
    case signInWithApple
}

enum AccountDeletionAuthPolicy {
    /// Apple Sign In–only users re-auth with Apple; everyone else uses password.
    static func preferredReauthMethod(session: Session) -> AccountDeletionReauthMethod {
        let providers = linkedProviders(from: session)
        let hasApple = providers.contains("apple")
        let hasEmail = providers.contains("email")
        if hasApple, !hasEmail {
            return .signInWithApple
        }
        return .password
    }

    static func linkedProviders(from session: Session) -> Set<String> {
        linkedProviders(user: session.user)
    }

    static func linkedProviders(user: Auth.User) -> Set<String> {
        var providers = Set<String>()
        if let identities = user.identities {
            for identity in identities {
                providers.insert(identity.provider.lowercased())
            }
        }
        if let raw = user.appMetadata["provider"]?.stringValue?.lowercased(), !raw.isEmpty {
            providers.insert(raw)
        }
        return providers
    }
}
