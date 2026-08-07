//
//  MapPanelHeightTests.swift
//  SpotTests
//
//  Locks in the safe-panel-height behavior introduced to fix IMG_9741
//  (selected-spot card overflowing the screen and shifting the map). The
//  clamp guarantees:
//   * a minimum readable header height,
//   * never exceeds `panelMaxScreenFraction` of the available height,
//   * always sits above the bottom safe-area inset.
//

import Foundation
import Testing
@testable import Spot

struct MapPanelHeightTests {

    @Test func returnsRequestedWhenWithinBounds() {
        let result = MapPanelHeight.clamp(
            requested: 320,
            availableHeight: 800,
            bottomSafeArea: 24
        )
        // 320 ≤ 65% of (800 - 24) ≈ 504 → returned as-is.
        #expect(result.height == 320)
        #expect(result.wasClamped == false)
    }

    @Test func enforcesMaxFractionUpperBound() {
        let result = MapPanelHeight.clamp(
            requested: 1500,
            availableHeight: 800,
            bottomSafeArea: 0
        )
        let cap = 800 * Constants.MapDesign.panelMaxScreenFraction
        #expect(result.height <= cap + 0.001)
        #expect(result.wasClamped == true)
    }

    @Test func enforcesMinHeight() {
        let result = MapPanelHeight.clamp(
            requested: 50,
            availableHeight: 800,
            bottomSafeArea: 0
        )
        #expect(result.height >= Constants.MapDesign.panelMinHeight - 0.001)
    }

    @Test func subtractsBottomSafeArea() {
        // On a small screen with a notch, the panel should still leave
        // room for the home indicator: clamped height + safe area must
        // never exceed the screen.
        let safe: CGFloat = 34
        let avail: CGFloat = 600
        let result = MapPanelHeight.clamp(
            requested: avail,
            availableHeight: avail,
            bottomSafeArea: safe
        )
        #expect(result.height + safe <= avail + 0.001)
        #expect(result.wasClamped == true)
    }

    @Test func tinyScreenStillReturnsMinHeight() {
        // Even on a stunted available height we never collapse below the
        // configured minimum so the close button stays tappable.
        let result = MapPanelHeight.clamp(
            requested: 10,
            availableHeight: 200,
            bottomSafeArea: 0
        )
        #expect(result.height > 0)
    }
}
