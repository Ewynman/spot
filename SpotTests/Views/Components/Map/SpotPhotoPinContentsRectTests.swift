//
//  SpotPhotoPinContentsRectTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import CoreGraphics
import Testing
@testable import Spot

struct SpotPhotoPinContentsRectTests {

    private let identity = CGRect(x: 0, y: 0, width: 1, height: 1)

    // MARK: - Landscape / square

    @Test func landscapeReturnsIdentityRect() {
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: CGSize(width: 1200, height: 800),
            biasShift: 0.10
        )
        #expect(rect == identity)
    }

    @Test func squareReturnsIdentityRect() {
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: CGSize(width: 500, height: 500),
            biasShift: 0.10
        )
        #expect(rect == identity)
    }

    // MARK: - Portrait

    @Test func portraitReturnsSquareSubregion() {
        let size = CGSize(width: 900, height: 1200) // aspect 0.75
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: 0.10
        )
        // Height must match the aspect ratio so the subregion is a
        // perfect square in image pixels (900 × 900).
        #expect(abs(rect.height - 0.75) < 1e-6)
        #expect(abs(rect.width - 1.0) < 1e-6)
        #expect(rect.origin.x == 0)
    }

    @Test func portraitYStartShiftsDownByBias() {
        let size = CGSize(width: 900, height: 1200) // aspect 0.75
        let biased = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: 0.10
        )
        let centered = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: 0
        )
        // Biased crop begins exactly `biasShift` further down the image
        // than a plain center crop.
        #expect(abs((biased.origin.y - centered.origin.y) - 0.10) < 1e-6)
        #expect(abs(centered.origin.y - 0.125) < 1e-6) // (1 - 0.75) / 2
        #expect(abs(biased.origin.y - 0.225) < 1e-6)
    }

    @Test func portraitBiasClampsWhenShiftWouldOvershootBottom() {
        // Aspect 0.9 → excess = 0.10, half excess = 0.05. Any bias >= 0.05
        // must clamp to 0.05 so the crop window still ends at y = 1.0.
        let size = CGSize(width: 900, height: 1000) // aspect 0.9
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: 0.20
        )
        // yStart = (1 - 0.9)/2 + clampedShift = 0.05 + 0.05 = 0.10
        // → yEnd = yStart + height = 0.10 + 0.9 = 1.0 exactly.
        #expect(abs(rect.origin.y - 0.10) < 1e-6)
        #expect(abs((rect.origin.y + rect.height) - 1.0) < 1e-6)
    }

    @Test func portraitVeryTallImageBiasStillFits() {
        // 1:2 portrait — plenty of headroom for a 10% shift.
        let size = CGSize(width: 500, height: 1000) // aspect 0.5
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: 0.10
        )
        #expect(abs(rect.height - 0.5) < 1e-6)
        #expect(abs(rect.origin.y - 0.35) < 1e-6) // 0.25 + 0.10
        #expect(rect.origin.y + rect.height <= 1.0 + 1e-6)
    }

    // MARK: - Degenerate inputs

    @Test func zeroWidthReturnsIdentityRect() {
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: CGSize(width: 0, height: 800),
            biasShift: 0.10
        )
        #expect(rect == identity)
    }

    @Test func zeroHeightReturnsIdentityRect() {
        let rect = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: CGSize(width: 800, height: 0),
            biasShift: 0.10
        )
        #expect(rect == identity)
    }

    @Test func negativeBiasClampsToZero() {
        // The runtime guards against a caller accidentally passing a
        // negative shift by clamping to 0 — the pin never drifts *up*.
        let size = CGSize(width: 900, height: 1200)
        let biased = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: -0.10
        )
        let centered = SpotPhotoPinContentsRect.contentsRect(
            forImageSize: size,
            biasShift: 0
        )
        #expect(abs(biased.origin.y - centered.origin.y) < 1e-6)
    }
}
