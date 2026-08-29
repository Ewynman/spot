//
//  DebugKeychainResetTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Security
import Testing
@testable import Spot

struct DebugKeychainResetTests {
    @Test func disabledRequestDoesNothing() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var deleteCallCount = 0

        let outcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: {
                deleteCallCount += 1
                return errSecSuccess
            }
        )

        #expect(outcome == nil)
        #expect(deleteCallCount == 0)
    }

    @Test func enabledRequestClearsOnceAndResetsToggle() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        defaults.set(true, forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch)
        var deleteCallCount = 0

        let firstOutcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: {
                deleteCallCount += 1
                return errSecSuccess
            }
        )
        let secondOutcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: {
                deleteCallCount += 1
                return errSecSuccess
            }
        )

        #expect(firstOutcome == .cleared)
        #expect(secondOutcome == nil)
        #expect(deleteCallCount == 1)
        #expect(!defaults.bool(forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch))
    }

    @Test(arguments: [
        (errSecItemNotFound, DebugKeychainReset.Outcome.nothingToClear),
        (errSecInteractionNotAllowed, DebugKeychainReset.Outcome.failed(errSecInteractionNotAllowed))
    ])
    func reportsDeleteOutcome(status: OSStatus, expected: DebugKeychainReset.Outcome) {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        defaults.set(true, forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch)

        let outcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: { status }
        )

        #expect(outcome == expected)
        #expect(!defaults.bool(forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch))
    }

    @Test func resetTargetsOnlyKnownSpotAuthenticationItems() {
        let queries = DebugKeychainReset.spotAuthenticationQueries()
        let services = queries.compactMap { $0[kSecAttrService as String] as? String }
        let accounts = queries.compactMap { $0[kSecAttrAccount as String] as? String }

        #expect(queries.count == 9)
        #expect(services.contains("supabase.gotrue.swift"))
        #expect(services.contains("com.edwardwynman.Spot.account-hint"))
        #expect(services.contains("com.edwardwynman.Spot.verification-recovery"))
        #expect(accounts.contains("com.spotapp.spot.supabaseAccessToken"))
        #expect(accounts.contains("com.spotapp.spot.tokenExpiration"))
        #expect(accounts.contains(
            "com.spotapp.spot.supabaseAccessToken.\(SupabaseEnvironment.stagingProjectRef)"
        ))
        #expect(accounts.contains(
            "com.spotapp.spot.supabaseAccessToken.\(SupabaseEnvironment.productionProjectRef)"
        ))
        #expect(accounts.contains(
            "com.spotapp.spot.tokenExpiration.\(SupabaseEnvironment.stagingProjectRef)"
        ))
        #expect(accounts.contains(
            "com.spotapp.spot.tokenExpiration.\(SupabaseEnvironment.productionProjectRef)"
        ))
        #expect(queries.allSatisfy {
            ($0[kSecClass as String] as? String) == (kSecClassGenericPassword as String)
        })
    }

    @Test func deletingKnownItemsAggregatesStatuses() {
        var noItemCalls = 0
        let noItems = DebugKeychainReset.deleteSpotAuthenticationItems { _ in
            noItemCalls += 1
            return errSecItemNotFound
        }
        #expect(noItems == errSecItemNotFound)
        #expect(noItemCalls == 9)

        var successCalls = 0
        let deleted = DebugKeychainReset.deleteSpotAuthenticationItems { _ in
            successCalls += 1
            return successCalls == 2 ? errSecSuccess : errSecItemNotFound
        }
        #expect(deleted == errSecSuccess)
        #expect(successCalls == 9)

        var failureCalls = 0
        let failed = DebugKeychainReset.deleteSpotAuthenticationItems { _ in
            failureCalls += 1
            return failureCalls == 2 ? errSecInteractionNotAllowed : errSecItemNotFound
        }
        #expect(failed == errSecInteractionNotAllowed)
        #expect(failureCalls == 2)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "DebugKeychainResetTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch)
    }
}
