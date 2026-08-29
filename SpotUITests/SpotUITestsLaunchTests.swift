//
//  SpotUITestsLaunchTests.swift
//  SpotUITests
//
//  Created by Edward Wynman on 7/10/25.
//

import XCTest

final class SpotUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchCompletesAndRendersInteractiveSurface() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyDefaultLaunchConfiguration(to: app)
        app.launch()

        // Cold launch should produce *some* tappable element within a
        // generous window, regardless of which gate the user lands on
        // (welcome, confirm-email, tab bar). If nothing is hittable, the
        // launch hung or crashed.
        let firstButton = app.buttons.firstMatch
        XCTAssertTrue(
            firstButton.waitForExistence(timeout: 20),
            "App launch should produce at least one interactive button within 20s"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
