//
//  SpotUITestAppConfiguration.swift
//  SpotUITests
//
//  Created by Edward Wynman on 8/28/26.
//

import XCTest

enum SpotUITestAppConfiguration {

    /// Standard UI test launch: enables DEBUG-only bootstrap in the host app (`SpotLaunchConfiguration`).
    static func applyDefaultLaunchConfiguration(to app: XCUIApplication) {
        app.launchArguments.append("--ui-testing")
        app.launchEnvironment["SPOT_UI_TEST_MODE"] = "1"
    }

    /// Synthetic signed-in shell for tab / posting smoke tests (no Supabase session; DEBUG only).
    static func applyLoggedInSyntheticSession(
        to app: XCUIApplication,
        accountDeletionReauth: String? = nil
    ) {
        applyDefaultLaunchConfiguration(to: app)
        app.launchEnvironment["SPOT_AUTH_STATE"] = "loggedIn"
        if let accountDeletionReauth {
            app.launchEnvironment["SPOT_ACCOUNT_DELETION_REAUTH"] = accountDeletionReauth
        }
    }
}
