//
//  SpotMediaAspectRatioTests.swift
//  SpotTests
//

import CoreGraphics
import Testing
@testable import Spot

struct SpotMediaAspectRatioTests {

    @Test func rawAndDisplaySquare() {
        #expect(SpotMediaAspectRatio.raw(width: 1080, height: 1080) == 1.0)
        #expect(SpotMediaAspectRatio.display(width: 1080, height: 1080) == 1.0)
    }

    @Test func displayClampsTallPortrait() {
        // 1080 x 1920 → raw ~0.5625 → clamp to 0.80
        let d = SpotMediaAspectRatio.display(width: 1080, height: 1920)
        #expect(abs(Double(d) - 0.80) < 0.001)
    }

    @Test func displayClampsVeryWide() {
        let d = SpotMediaAspectRatio.display(width: 3000, height: 1000)
        #expect(abs(Double(d) - 1.91) < 0.001)
    }

    @Test func displayPreservesLandscapeWithinBand() {
        let d = SpotMediaAspectRatio.display(width: 1920, height: 1080)
        #expect(abs(Double(d) - (1920.0 / 1080.0)) < 0.001)
    }

    @Test func fallbackWhenDimensionsMissing() {
        #expect(SpotMediaAspectRatio.raw(width: nil, height: nil) == SpotMediaAspectRatio.fallbackRatio)
        #expect(SpotMediaAspectRatio.display(width: 0, height: 100) == SpotMediaAspectRatio.fallbackRatio)
    }

    @Test func mediaHeightClamps() {
        let h = SpotMediaAspectRatio.mediaHeight(
            containerWidth: 350,
            displayRatio: 0.8,
            minHeight: 180,
            maxHeight: 520
        )
        #expect(h <= 520)
        #expect(h >= 180)
    }

    @Test func effectiveRatioUsesSpotProperty() {
        let s = Spot(
            id: "1",
            mediaDisplayAspectRatio: 1.78,
            mediaCount: 1
        )
        let r = SpotMediaAspectRatio.effectiveDisplayRatio(for: s)
        #expect(abs(Double(r) - 1.78) < 0.001)
    }

}
