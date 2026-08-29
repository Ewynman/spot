//
//  SpotLaunchConfiguration.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotLaunchConfiguration {

    /// True when the process is hosted by XCTest (unit test runs).
    /// Used to skip side-effectful initialisation (e.g. Firebase) that would
    /// crash the host app when required resources are absent during CI.
    static var isUnitTestMode: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    /// True when UI tests set `SPOT_UI_TEST_MODE=1` or `--ui-testing` (DEBUG only).
    static var isUITestMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SPOT_UI_TEST_MODE"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }

    /// Synthetic auth presentation for UI tests (requires `isUITestMode`).
    enum UITestAuthBootstrap: String {
        case loggedIn
        case loggedOut
    }

    /// Defaults to `.loggedOut` whenever UI-test mode is on but `SPOT_AUTH_STATE` is unset.
    static var uiTestAuthBootstrap: UITestAuthBootstrap? {
        #if DEBUG
        guard isUITestMode else { return nil }
        if let raw = ProcessInfo.processInfo.environment["SPOT_AUTH_STATE"],
           let value = UITestAuthBootstrap(rawValue: raw) {
            return value
        }
        return .loggedOut
        #else
        nil
        #endif
    }

    /// Stable synthetic user id for UI tests (`SPOT_AUTH_STATE=loggedIn`).
    static let uiTestSyntheticUserId = "00000000-0000-0000-0000-0000000000AA"

    /// `SPOT_USER_TIER=pro` sets Pro in synthetic auth (DEBUG + UI test only).
    static var uiTestUserIsPro: Bool {
        #if DEBUG
        guard isUITestMode else { return false }
        return ProcessInfo.processInfo.environment["SPOT_USER_TIER"] == "pro"
        #else
        false
        #endif
    }

    /// Overrides account-deletion re-auth UI: `password` (default) or `apple`.
    static var uiTestAccountDeletionReauth: AccountDeletionReauthMethod? {
        #if DEBUG
        guard isUITestMode,
              let raw = ProcessInfo.processInfo.environment["SPOT_ACCOUNT_DELETION_REAUTH"]
        else { return nil }
        switch raw.lowercased() {
        case "apple": return .signInWithApple
        case "password": return .password
        default: return nil
        }
        #else
        nil
        #endif
    }
}
