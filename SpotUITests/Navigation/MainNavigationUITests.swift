//
//  MainNavigationUITests.swift
//  SpotUITests
//
//  Created by Edward Wynman on 8/28/26.
//

import XCTest

final class MainNavigationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSyntheticSessionShowsTabShellAndHomeFeed() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        let shell = app.descendants(matching: .any)["main.tabShell"]
        XCTAssertTrue(shell.waitForExistence(timeout: 25), "Synthetic session should present main tab shell")

        let home = app.buttons["navigation.homeTab"]
        XCTAssertTrue(home.waitForExistence(timeout: 5), "Home tab should be identifiable")

        let feed = app.descendants(matching: .any)["home.feedRoot"]
        XCTAssertTrue(feed.waitForExistence(timeout: 20), "Home feed surface should appear for default tab")
    }

    @MainActor
    func testCanSwitchToMapSearchProfileTabs() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))

        let mapTab = app.buttons["navigation.mapTab"]
        let searchTab = app.buttons["navigation.searchTab"]
        let profileTab = app.buttons["navigation.profileTab"]

        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["map.screen"].waitForExistence(timeout: 15))

        searchTab.tap()
        XCTAssertTrue(searchTab.waitForExistence(timeout: 3))

        profileTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.screenRoot"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testRetappingProfileTabDismissesPushedSettings() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))

        let profileTab = app.buttons["navigation.profileTab"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.screenRoot"].waitForExistence(timeout: 20))

        let menu = app.buttons["profile.menuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()

        let settingsEntry = app.buttons["profile.settingsEntry"]
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 5))
        settingsEntry.tap()

        let settingsRoot = app.descendants(matching: .any)["settings.screenRoot"]
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 10))

        profileTab.tap()

        let settingsGone = NSPredicate(format: "exists == false")
        expectation(for: settingsGone, evaluatedWith: settingsRoot, handler: nil)
        waitForExpectations(timeout: 8)
    }
}
