//
//  DebugKeychainReset.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Security

enum DebugKeychainReset {
    enum Outcome: Equatable {
        case cleared
        case nothingToClear
        case failed(OSStatus)
    }

    /// Runs before the Supabase client is constructed so no persisted session
    /// can be restored first. The preference is always reset for one-shot use.
    @discardableResult
    static func performIfRequested() -> Outcome? {
        #if DEBUG
        performIfRequested(
            defaults: .standard,
            deleteItems: { deleteSpotAuthenticationItems() }
        )
        #else
        nil
        #endif
    }

    #if DEBUG
    @discardableResult
    static func performIfRequested(
        defaults: UserDefaults,
        deleteItems: () -> OSStatus
    ) -> Outcome? {
        let key = Constants.UserDefaultsKeys.clearKeychainOnNextLaunch
        guard defaults.bool(forKey: key) else { return nil }

        defaults.set(false, forKey: key)
        let status = deleteItems()

        switch status {
        case errSecSuccess:
            SpotLogger.log(DebugKeychainResetLogs.cleared)
            return .cleared
        case errSecItemNotFound:
            SpotLogger.log(DebugKeychainResetLogs.nothingToClear)
            return .nothingToClear
        default:
            SpotLogger.log(
                DebugKeychainResetLogs.failed,
                details: ["status": status]
            )
            return .failed(status)
        }
    }

    static func deleteSpotAuthenticationItems(
        deleteQuery: ([String: Any]) -> OSStatus = {
            SecItemDelete($0 as CFDictionary)
        }
    ) -> OSStatus {
        var deletedAnItem = false
        for query in spotAuthenticationQueries() {
            let status = deleteQuery(query)
            switch status {
            case errSecSuccess:
                deletedAnItem = true
            case errSecItemNotFound:
                continue
            default:
                return status
            }
        }
        return deletedAnItem ? errSecSuccess : errSecItemNotFound
    }

    static func spotAuthenticationQueries() -> [[String: Any]] {
        let serviceQueries = [
            serviceQuery("supabase.gotrue.swift"),
            serviceQuery(
                "com.edwardwynman.Spot.account-hint",
                account: "last-account"
            ),
            serviceQuery(
                "com.edwardwynman.Spot.verification-recovery",
                account: "pending-signup"
            )
        ]
        let tokenKeyBases = [
            "com.spotapp.spot.supabaseAccessToken",
            "com.spotapp.spot.tokenExpiration"
        ]
        let projectRefs = [
            SupabaseEnvironment.stagingProjectRef,
            SupabaseEnvironment.productionProjectRef
        ]
        let tokenQueries = tokenKeyBases.flatMap { base in
            [accountQuery(base)] + projectRefs.map { accountQuery("\(base).\($0)") }
        }
        return serviceQueries + tokenQueries
    }

    private static func serviceQuery(
        _ service: String,
        account: String? = nil
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        return query
    }

    private static func accountQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
    }
    #endif
}
