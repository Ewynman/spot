//
//  PhotoPinGeometryTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import CoreGraphics
import Testing
@testable import Spot

struct PhotoPinGeometryTests {

    private var sampleRect: CGRect {
        CGRect(
            x: 0,
            y: 0,
            width: Constants.MapDesign.photoPinImageDiameter,
            height: Constants.MapDesign.photoPinTotalHeight
        )
    }

    // MARK: - Layout helper

    @Test func photoPinLayoutTipSitsAtRectBottom() {
        let layout = SpotMarkerGeometry.photoPinLayout(in: sampleRect)
        #expect(layout.tip.x == sampleRect.midX)
        #expect(layout.tip.y == sampleRect.maxY)
    }

    @Test func photoPinLayoutBubbleIsTopAnchoredCircle() {
        let layout = SpotMarkerGeometry.photoPinLayout(in: sampleRect)
        #expect(layout.imageCircle.origin == sampleRect.origin)
        #expect(layout.imageCircle.width == sampleRect.width)
        #expect(layout.imageCircle.height == sampleRect.width)
        #expect(layout.bubbleCenter.x == sampleRect.midX)
        #expect(layout.bubbleCenter.y == sampleRect.minY + layout.radius)
    }

    @Test func photoPinLayoutImageContentInsetByBorderWidth() {
        let layout = SpotMarkerGeometry.photoPinLayout(in: sampleRect)
        let expected = layout.imageCircle.insetBy(
            dx: Constants.MapDesign.photoPinBorderWidth,
            dy: Constants.MapDesign.photoPinBorderWidth
        )
        #expect(layout.imageContent == expected)
    }

    @Test func photoPinLayoutClampsBorderThatExceedsRadius() {
        let layout = SpotMarkerGeometry.photoPinLayout(
            in: sampleRect,
            borderWidth: 999
        )
        // The image content is never inverted or empty when a caller
        // requests an absurdly thick border — it collapses to a 2-pt
        // circle at the bubble center.
        #expect(layout.imageContent.width > 0)
        #expect(layout.imageContent.height > 0)
        #expect(layout.imageContent.midX == layout.bubbleCenter.x)
        #expect(layout.imageContent.midY == layout.bubbleCenter.y)
    }

    // MARK: - Shell path

    @Test func photoPinPathIsClosedAndTerminatesAtTip() {
        let layout = SpotMarkerGeometry.photoPinLayout(in: sampleRect)
        let path = SpotMarkerGeometry.photoPinPath(layout)
        // `closeSubpath` returns cursor to the starting point (tip).
        #expect(path.currentPoint.x == layout.tip.x)
        #expect(path.currentPoint.y == layout.tip.y)
    }

    @Test func photoPinPathContainsBubbleCenter() {
        let layout = SpotMarkerGeometry.photoPinLayout(in: sampleRect)
        let path = SpotMarkerGeometry.photoPinPath(layout)
        #expect(path.contains(layout.bubbleCenter))
    }

    @Test func photoPinPathExtendsAllTheWayToRectBounds() {
        let layout = SpotMarkerGeometry.photoPinLayout(in: sampleRect)
        let path = SpotMarkerGeometry.photoPinPath(layout)
        // The path bounds hug the rect on all sides. `boundingBoxOfPath`
        // includes cubic control points; MapKit uses `boundingBox`
        // (visual extent), so a sub-pixel overshoot at the top is
        // acceptable and never renders outside the annotation view frame.
        let bounds = path.boundingBoxOfPath
        let tolerance: CGFloat = 0.5
        #expect(bounds.maxY == sampleRect.maxY)
        #expect(abs(bounds.minY - sampleRect.minY) < tolerance)
        #expect(abs(bounds.width - sampleRect.width) < tolerance)
    }

    @Test func photoPinPathTipMatchesGeographicAnchor() {
        // Regression: the tip must remain at (midX, maxY) for arbitrary
        // rect origins — the annotation view sets `centerOffset` off
        // `frame.height / 2` on the assumption that (midX, maxY) is the
        // geographic anchor.
        let shifted = CGRect(x: 12, y: 34, width: 44, height: 56)
        let layout = SpotMarkerGeometry.photoPinLayout(in: shifted)
        #expect(layout.tip == CGPoint(x: shifted.midX, y: shifted.maxY))
    }
}
