//
//  AuthGateUITests.swift
//  SpotUITests
//

import XCTest

final class AuthGateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeShowsStableIdentifiersWhenLoggedOut() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyDefaultLaunchConfiguration(to: app)
        app.launch()

        let getStarted = app.buttons["onboarding.getStartedButton"]
        let login = app.buttons["auth.loginButton"]
        let apple = app.descendants(matching: .any)["auth.signInWithAppleButton"]

        XCTAssertTrue(
            getStarted.waitForExistence(timeout: 20),
            "Get Started should use accessibility identifier onboarding.getStartedButton"
        )
        XCTAssertTrue(login.exists, "Log in should use accessibility identifier auth.loginButton")
        XCTAssertTrue(apple.exists, "Apple sign-in control should expose auth.signInWithAppleButton")
    }

    @MainActor
    func testLoginEntryNavigatesAwayFromWelcome() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyDefaultLaunchConfiguration(to: app)
        app.launch()

        let login = app.buttons["auth.loginButton"]
        guard login.waitForExistence(timeout: 20) else {
            throw XCTSkip("Welcome not reachable — likely already signed in on this simulator.")
        }
        let terms = app.buttons["auth.termsCheckbox"]
        if terms.waitForExistence(timeout: 3) {
            terms.tap()
        }
        login.tap()

        let loginScreen = app.descendants(matching: .any)["auth.login.screen"]
        let email = app.textFields["auth.login.emailField"]
        XCTAssertTrue(
            loginScreen.waitForExistence(timeout: 12) || email.waitForExistence(timeout: 12),
            "Login flow should show the redesigned Log in screen"
        )
    }
}
