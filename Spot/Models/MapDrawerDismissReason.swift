//
//  MapDrawerDismissReason.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import MapKit

enum MapDrawerDismissReason: String, Equatable, Sendable {
    case closeButton
    case mapMoved
    case emptyMapTap
    case filterChanged
    case selectedSpotNoLongerVisible
    case spotSwitch
    case tabLeft
    case tabReselected
}

/// Heuristics for drawer dismissal vs programmatic camera moves.
enum MapDiscoveryDrawerPolicy {
    /// Suppress treating map region updates as user pan/zoom right after we
    /// drive the camera for marker selection (focus lift / programmatic fit).
    static let programmaticCameraSuppressionSeconds: TimeInterval = 0.55

    /// Whether two regions differ enough to treat as user pan/zoom.
    static func regionsMeaningfullyDiffer(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let centerDeltaLat = abs(a.center.latitude - b.center.latitude)
        let centerDeltaLon = abs(a.center.longitude - b.center.longitude)
        let spanA = max(a.span.latitudeDelta, a.span.longitudeDelta)
        let spanB = max(b.span.latitudeDelta, b.span.longitudeDelta)
        let spanDelta = abs(spanA - spanB) / max(spanA, spanB, 1e-9)
        let centerMoved = centerDeltaLat > 1e-5 || centerDeltaLon > 1e-5
        let zoomChanged = spanDelta > 0.015
        return centerMoved || zoomChanged
    }
}
