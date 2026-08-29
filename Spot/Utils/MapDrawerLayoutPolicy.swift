//
//  MapDrawerLayoutPolicy.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreGraphics
import Foundation

/// Pure height composition for the map spot drawer (no GeometryProxy).
enum MapDrawerLayoutPolicy {
    static func expandedHeight(
        screenHeight: CGFloat,
        bottomSafeArea: CGFloat,
        topReveal: CGFloat = 8,
        maxScreenFraction: CGFloat,
        minHeight: CGFloat
    ) -> CGFloat {
        let usable = screenHeight - bottomSafeArea - topReveal
        let maxDrawer = screenHeight * maxScreenFraction
        return max(minHeight, min(usable, maxDrawer))
    }

    static func maxHeightBelowFilterPills(
        screenHeight: CGFloat,
        bottomPadding: CGFloat,
        pillsBottomY: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        let topOfDrawer = pillsBottomY + gap
        return max(0, screenHeight - topOfDrawer - bottomPadding)
    }

    static func filterPillsBottomY(
        measuredMaxY: CGFloat?,
        safeAreaTop: CGFloat,
        fallbackChrome: CGFloat = 52
    ) -> CGFloat {
        if let y = measuredMaxY, y > 1 { return y }
        return safeAreaTop + fallbackChrome
    }

    static func resolvedHeight(
        requested: CGFloat,
        ceiling: CGFloat,
        minHeight: CGFloat
    ) -> CGFloat {
        max(minHeight, min(requested, ceiling))
    }
}
