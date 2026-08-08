//
//  PostingFlowUITests.swift
//  SpotUITests
//

import XCTest

final class PostingFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPostTabReachesComposerOrVerificationGate() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))

        let postTab = app.buttons["navigation.postTab"]
        XCTAssertTrue(postTab.waitForExistence(timeout: 5))
        postTab.tap()

        let photoStep = app.descendants(matching: .any)["posting.photoStepRoot"]
        let verifyGate = app.staticTexts["Verify your email to post"]
        let settled = photoStep.waitForExistence(timeout: 20) || verifyGate.waitForExistence(timeout: 20)

        XCTAssertTrue(settled, "Post tab should show composer or email verification gate")
    }

    @MainActor
    func testDraftsControlExistsOnPhotoStep() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))
        app.buttons["navigation.postTab"].tap()

        let drafts = app.buttons["posting.draftsButton"]
        let photoStep = app.descendants(matching: .any)["posting.photoStepRoot"]
        let verifyGate = app.staticTexts["Verify your email to post"]

        if verifyGate.waitForExistence(timeout: 6) {
            throw XCTSkip("Synthetic session is not email-verified in this build; drafts UI not reachable.")
        }

        XCTAssertTrue(photoStep.waitForExistence(timeout: 20))
        XCTAssertTrue(drafts.exists, "Drafts affordance should remain discoverable on the photo step")
    }

    @MainActor
    func testPhotoStepShowsChoosePhotosControl() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))
        app.buttons["navigation.postTab"].tap()

        if app.staticTexts["Verify your email to post"].waitForExistence(timeout: 6) {
            throw XCTSkip("Synthetic session is not email-verified in this build; photo composer not reachable.")
        }

        let photoStep = app.descendants(matching: .any)["posting.photoStepRoot"]
        XCTAssertTrue(photoStep.waitForExistence(timeout: 20))

        let choose = app.buttons["posting.choosePhotosButton"]
        XCTAssertTrue(choose.waitForExistence(timeout: 8), "Choose photos control should render on empty photo step")
    }
}
