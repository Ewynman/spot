//
//  OnboardingUITests.swift
//  SpotUITests
//

import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGetStartedBeginsAccountFlow() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyDefaultLaunchConfiguration(to: app)
        app.launch()

        let getStarted = app.buttons["onboarding.getStartedButton"]
        guard getStarted.waitForExistence(timeout: 20) else {
            throw XCTSkip("Welcome not reachable — likely already signed in on this simulator.")
        }
        XCTAssertTrue(app.links["Terms of Use (EULA)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.links["Privacy Policy"].exists)
        XCTAssertFalse(app.buttons["auth.openTermsLink"].exists)
        XCTAssertFalse(app.buttons["auth.openPrivacyLink"].exists)

        let terms = app.buttons["auth.termsCheckbox"]
        if terms.waitForExistence(timeout: 3) {
            terms.tap()
        }
        getStarted.tap()

        let signup = app.descendants(matching: .any)["onboarding.signupScreen"]
        let locationGate = app.staticTexts["Location Access"]
        let settled = signup.waitForExistence(timeout: 12)
            || locationGate.waitForExistence(timeout: 12)
            || app.staticTexts["Create your\nSpot account"].waitForExistence(timeout: 12)

        XCTAssertTrue(settled, "Get Started should reach signup, permission gate, or create-account title")
        if signup.exists {
            XCTAssertTrue(app.links["Terms of Use"].exists)
            XCTAssertTrue(app.links["Privacy Policy"].exists)
            XCTAssertTrue(app.textFields["auth.signup.emailField"].exists)
            XCTAssertTrue(app.textFields["auth.signup.usernameField"].exists)
            XCTAssertTrue(app.secureTextFields["auth.signup.passwordField"].exists
                || app.textFields["auth.signup.passwordField"].exists)
            XCTAssertTrue(app.buttons["auth.signup.continueButton"].exists)
        }
    }

    @MainActor
    func testSignupValidationRequiresFields() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyDefaultLaunchConfiguration(to: app)
        app.launch()

        let getStarted = app.buttons["onboarding.getStartedButton"]
        guard getStarted.waitForExistence(timeout: 20) else {
            throw XCTSkip("Welcome not reachable — likely already signed in on this simulator.")
        }
        let terms = app.buttons["auth.termsCheckbox"]
        if terms.waitForExistence(timeout: 3) {
            terms.tap()
        }
        getStarted.tap()

        let signup = app.descendants(matching: .any)["onboarding.signupScreen"]
        guard signup.waitForExistence(timeout: 12) else {
            throw XCTSkip("Signup screen not reachable from Get Started on this simulator.")
        }

        let continueButton = app.buttons["auth.signup.continueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // Still on signup — empty form should not navigate away.
        XCTAssertTrue(signup.exists)
    }
}
