//
//  AccountDeletionUITests.swift
//  SpotUITests
//
//  Created by Edward Wynman on 8/28/26.
//

import XCTest

final class AccountDeletionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDeleteAccountPasswordPathIsReachable() throws {
        let app = launchLoggedIn(accountDeletionReauth: "password")
        openAccountSettings(in: app)

        let screen = app.descendants(matching: .any)["settings.accountSettingsScreen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 12))

        XCTAssertTrue(app.switches["settings.deleteAccountConfirmToggle"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.secureTextFields["settings.deleteAccountPasswordField"].exists)
        XCTAssertTrue(app.buttons["settings.deleteAccountButton"].exists)
        XCTAssertFalse(app.buttons["settings.deleteAccountAppleButton"].exists)
    }

    @MainActor
    func testDeleteAccountAppleReauthPathIsReachable() throws {
        let app = launchLoggedIn(accountDeletionReauth: "apple")
        openAccountSettings(in: app)

        let screen = app.descendants(matching: .any)["settings.accountSettingsScreen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 12))

        XCTAssertTrue(app.switches["settings.deleteAccountConfirmToggle"].waitForExistence(timeout: 6))
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.deleteAccountAppleButton"].waitForExistence(timeout: 8)
        )
        XCTAssertFalse(app.buttons["settings.deleteAccountButton"].exists)
        XCTAssertFalse(app.secureTextFields["settings.deleteAccountPasswordField"].exists)
    }

    @MainActor
    func testContactSupportRowOpensSupportScreen() throws {
        let app = launchLoggedIn()
        navigateToSettings(in: app)

        let supportRow = app.buttons["settings.contactSupportRow"]
        XCTAssertTrue(supportRow.waitForExistence(timeout: 8))
        supportRow.tap()

        XCTAssertTrue(app.buttons["settings.supportEmailButton"].waitForExistence(timeout: 8))
    }

    // MARK: - Navigation

    @MainActor
    private func launchLoggedIn(accountDeletionReauth: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(
            to: app,
            accountDeletionReauth: accountDeletionReauth
        )
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))
        return app
    }

    @MainActor
    private func navigateToSettings(in app: XCUIApplication) {
        let profileTab = app.buttons["navigation.profileTab"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab should be visible in the tab shell")
        profileTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.screenRoot"].waitForExistence(timeout: 20))

        let menu = app.buttons["profile.menuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap()

        let settingsEntry = app.buttons["profile.settingsEntry"]
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 6))
        settingsEntry.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings.screenRoot"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func openAccountSettings(in app: XCUIApplication) {
        navigateToSettings(in: app)

        let accountEntry = app.buttons["settings.accountSettingsEntry"]
        XCTAssertTrue(accountEntry.waitForExistence(timeout: 8))
        accountEntry.tap()
    }
}
