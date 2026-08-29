//
//  ProfileSettingsUITests.swift
//  SpotUITests
//
//  Created by Edward Wynman on 8/28/26.
//

import XCTest

final class ProfileSettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testProfileTabShowsSelfProfileChrome() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))

        app.buttons["navigation.profileTab"].tap()

        let profileRoot = app.descendants(matching: .any)["profile.screenRoot"]
        XCTAssertTrue(profileRoot.waitForExistence(timeout: 20))

        let menu = app.buttons["profile.menuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap()

        let settingsEntry = app.buttons["profile.settingsEntry"]
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 6))
        settingsEntry.tap()

        let settingsRoot = app.descendants(matching: .any)["settings.screenRoot"]
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 15), "Settings should present settings.screenRoot")

        let account = app.buttons["settings.accountSettingsEntry"]
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        account.tap()

        let accountScreen = app.descendants(matching: .any)["settings.accountSettingsScreen"]
        XCTAssertTrue(accountScreen.waitForExistence(timeout: 10), "Account settings should open from settings list")
    }
}
