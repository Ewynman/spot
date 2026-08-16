//
//  HomeSpotCardUITests.swift
//  SpotUITests
//

import XCTest

final class HomeSpotCardUITests: XCTestCase {

    private enum Identifier {
        static let card = "home.spotCard"
        static let flip = "home.spotCard.flip"
        static let openInMap = "home.spotCard.openInMap"
        static let like = "home.spotCard.like"
        static let bookmark = "spot.bookmark"

        static let all = [card, flip, openInMap, like, bookmark]
    }

    /// Keeps the planned accessibility contract visible and compile-checked.
    ///
    /// The existing synthetic signed-in launch mode does not inject feed rows,
    /// so an interaction test would depend on live Supabase data. Once a
    /// deterministic Home-card fixture is available, use `elements(in:)` to
    /// exercise flip, Like, Save, and the in-app Map handoff.
    func testAccessibilityIdentifierContract() {
        XCTAssertEqual(
            Identifier.all,
            [
                "home.spotCard",
                "home.spotCard.flip",
                "home.spotCard.openInMap",
                "home.spotCard.like",
                "spot.bookmark"
            ]
        )
        XCTAssertEqual(Set(Identifier.all).count, Identifier.all.count)
    }

    @MainActor
    private func elements(in app: XCUIApplication) -> (
        card: XCUIElement,
        flip: XCUIElement,
        openInMap: XCUIElement,
        like: XCUIElement,
        bookmark: XCUIElement
    ) {
        (
            app.descendants(matching: .any)[Identifier.card],
            app.buttons[Identifier.flip],
            app.buttons[Identifier.openInMap],
            app.buttons[Identifier.like],
            app.buttons[Identifier.bookmark]
        )
    }
}
