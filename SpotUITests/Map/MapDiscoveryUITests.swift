//
//  MapDiscoveryUITests.swift
//  SpotUITests
//

import XCTest

final class MapDiscoveryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMapTabShowsMapHost() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))

        app.buttons["navigation.mapTab"].tap()

        let mapHost = app.descendants(matching: .any)["map.mapView"]
        XCTAssertTrue(mapHost.waitForExistence(timeout: 20), "Map tab should host map.mapView")

        let mapScreen = app.descendants(matching: .any)["map.screen"]
        XCTAssertTrue(mapScreen.exists, "Map screen container should be present")
    }

    @MainActor
    func testProTierShowsFilterChrome() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launchEnvironment["SPOT_USER_TIER"] = "pro"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))
        app.buttons["navigation.mapTab"].tap()

        let filter = app.descendants(matching: .any)["map.filterButton"]
        XCTAssertTrue(filter.waitForExistence(timeout: 15), "Pro synthetic session should surface map filter chrome")
    }

    @MainActor
    func testFreeTierHidesFilterChrome() throws {
        let app = XCUIApplication()
        SpotUITestAppConfiguration.applyLoggedInSyntheticSession(to: app)
        app.launchEnvironment["SPOT_USER_TIER"] = "free"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabShell"].waitForExistence(timeout: 25))
        app.buttons["navigation.mapTab"].tap()

        let mapHost = app.descendants(matching: .any)["map.mapView"]
        XCTAssertTrue(mapHost.waitForExistence(timeout: 20))

        let filter = app.descendants(matching: .any)["map.filterButton"]
        XCTAssertFalse(
            filter.waitForExistence(timeout: 3),
            "Free synthetic session should not surface Pro-only map filter chrome"
        )
    }
}
