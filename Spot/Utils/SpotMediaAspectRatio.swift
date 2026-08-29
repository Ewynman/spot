//
//  SpotMediaAspectRatio.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Presentation buckets for min/max media height (pt) on top of the same ratio model.
enum SpotMediaPresentationContext: Equatable {
    case feed
    case detail
    case mapDrawer
    case postingPreview

    var minMediaHeight: CGFloat {
        switch self {
        case .feed: return 180
        case .detail: return 200
        case .mapDrawer: return 140
        case .postingPreview: return 180
        }
    }

    var maxMediaHeight: CGFloat {
        switch self {
        case .feed: return 520
        case .detail: return 620
        case .mapDrawer: return 320
        case .postingPreview: return 520
        }
    }
}

enum SpotMediaAspectRatio {
    static let minRatio: CGFloat = 0.80
    static let maxRatio: CGFloat = 1.91
    static let fallbackRatio: CGFloat = 1.0

    /// Raw pixel width / height (landscape > 1, portrait < 1).
    static func raw(width: Int?, height: Int?) -> CGFloat {
        guard let width, let height, width > 0, height > 0 else {
            return fallbackRatio
        }
        return CGFloat(width) / CGFloat(height)
    }

    static func display(width: Int?, height: Int?) -> CGFloat {
        let ratio = raw(width: width, height: height)
        return clampDisplayRatio(ratio)
    }

    static func clampDisplayRatio(_ ratio: CGFloat) -> CGFloat {
        guard ratio.isFinite, ratio > 0 else { return fallbackRatio }
        return min(max(ratio, minRatio), maxRatio)
    }

    /// Height for a fixed-width media shell: `height = width / displayRatio`.
    static func mediaHeight(
        containerWidth: CGFloat,
        displayRatio: CGFloat?,
        minHeight: CGFloat = SpotMediaPresentationContext.feed.minMediaHeight,
        maxHeight: CGFloat = SpotMediaPresentationContext.feed.maxMediaHeight
    ) -> CGFloat {
        let safeRatio = max((displayRatio.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }) ?? fallbackRatio, 0.1)
        let rawHeight = containerWidth / safeRatio
        return min(max(rawHeight, minHeight), maxHeight)
    }

    /// Uses persisted server ratio when present; otherwise canonical fallback.
    static func effectiveDisplayRatio(for spot: Spot) -> CGFloat {
        if let stored = spot.mediaDisplayAspectRatio, stored.isFinite, stored > 0 {
            return clampDisplayRatio(CGFloat(stored))
        }
        return fallbackRatio
    }

    /// Feed-style card content width when the host only has screen metrics (SpotCard inner padding 12+12).
    static func estimatedFeedContentWidth(screenWidth: CGFloat = SpotMediaLayoutMetrics.screenWidth) -> CGFloat {
        max(screenWidth - 24, 1)
    }
}

enum SpotMediaLayoutMetrics {
    static var screenWidth: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width
        #else
        return 390
        #endif
    }
}
