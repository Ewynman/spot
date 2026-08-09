//
//  MapClusterStyle.swift
//  Spot
//
//  Pure helpers for MapKit cluster marker sizing and coincident-cluster
//  detection. Kept view-free for unit testing.
//

import Foundation
import CoreLocation
import MapKit

enum MapClusterSizeBucket: Equatable, Sendable {
    case small   // 1–9
    case medium  // 10–99
    case large   // 100+
}

enum MapClusterStyle {

    static func sizeBucket(forCount count: Int) -> MapClusterSizeBucket {
        switch count {
        case ...9: return .small
        case 10...99: return .medium
        default: return .large
        }
    }

    static func pointSize(forCount count: Int) -> CGFloat {
        switch sizeBucket(forCount: count) {
        case .small: return Constants.MapDesign.clusterSizeSmall
        case .medium: return Constants.MapDesign.clusterSizeMedium
        case .large: return Constants.MapDesign.clusterSizeLarge
        }
    }

    /// Count label for the cluster badge.
    static func countLabel(forCount count: Int) -> String {
        if count > 999 { return "999+" }
        return "\(max(count, 0))"
    }

    /// True when member annotations share effectively the same coordinate
    /// (further zoom would not meaningfully separate them).
    static func isCoincident(_ annotations: [MKAnnotation]) -> Bool {
        let coords = annotations.map(\.coordinate)
        guard let first = coords.first else { return false }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for c in coords.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        let threshold = Constants.MapDesign.coincidentClusterSpan
        return latSpan <= threshold && lonSpan <= threshold
    }

    /// Camera lift for the compact preview card so the pin sits in the
    /// unobstructed map region above the card.
    static func compactPreviewCameraLift(cardHeight: CGFloat) -> CGFloat {
        max(Constants.MapDesign.selectedPinCameraLift, cardHeight * 0.55)
    }
}
