//
//  LaunchUITests.swift
//  SpotUITests
//
//  Created by Edward Wynman on 8/28/26.
//

import XCTest

final class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testColdLaunchReachesWelcomeOrAuthSurface() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyDefaultLaunchConfiguration(to: app)
        app.launch()

        let welcome = app.descendants(matching: .any)["welcome.screen"]
        let getStarted = app.buttons["onboarding.getStartedButton"]
        let login = app.buttons["auth.loginButton"]

        let settled = welcome.waitForExistence(timeout: 20)
            || getStarted.waitForExistence(timeout: 20)
            || login.waitForExistence(timeout: 20)

        XCTAssertTrue(
            settled,
            "Unauthenticated launch should surface welcome identifiers or primary CTAs"
        )
    }
}
