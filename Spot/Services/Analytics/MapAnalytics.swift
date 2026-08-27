//
//  MapAnalytics.swift
//  Spot
//
//  Firebase Analytics events for the redesigned map experience.
//

import Foundation

enum MapAnalyticsSurface: String {
    case global
    case profile
}

/// Identifier for the visual style of a map marker at the moment an
/// analytics event fires. Written to Firebase as-is so both variants are
/// visible in `map_marker_tapped` / `map_marker_impression` breakdowns
/// during and after the Concept 3 rollout.
enum MapMarkerAnalyticsType: String {
    case photoPin = "photo_pin"
    case teardrop
}

@MainActor
enum MapAnalytics {
    static func markerTapped(
        surface: MapAnalyticsSurface,
        spotId: String?,
        markerType: MapMarkerAnalyticsType = .photoPin,
        zoomLevel: Double? = nil
    ) {
        var params: [String: Any] = [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil",
            "marker_type": markerType.rawValue
        ]
        if let zoomLevel {
            params["zoom_level"] = zoomLevel
        }
        AnalyticsService.shared.logEvent("map_marker_tapped", parameters: params)
    }

    static func markerImpression(
        surface: MapAnalyticsSurface,
        spotId: String?,
        markerType: MapMarkerAnalyticsType = .photoPin,
        zoomLevel: Double? = nil
    ) {
        var params: [String: Any] = [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil",
            "marker_type": markerType.rawValue
        ]
        if let zoomLevel {
            params["zoom_level"] = zoomLevel
        }
        AnalyticsService.shared.logEvent("map_marker_impression", parameters: params)
    }

    static func markerImageLoad(
        surface: MapAnalyticsSurface,
        spotId: String?,
        source: MapMarkerImageLoadSource,
        success: Bool,
        loadTimeMs: Int
    ) {
        AnalyticsService.shared.logEvent("map_marker_image_load", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil",
            "load_source": source.rawValue,
            "success": success,
            "load_time_ms": max(0, loadTimeMs)
        ])
    }

    static func clusterTapped(surface: MapAnalyticsSurface, memberCount: Int) {
        AnalyticsService.shared.logEvent("map_cluster_tapped", parameters: [
            "surface": surface.rawValue,
            "member_count": memberCount
        ])
    }

    static func previewShown(surface: MapAnalyticsSurface, spotId: String?) {
        AnalyticsService.shared.logEvent("map_spot_preview_shown", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil"
        ])
    }

    static func previewLiked(surface: MapAnalyticsSurface, spotId: String?, isLiked: Bool) {
        AnalyticsService.shared.logEvent("map_preview_liked", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil",
            "is_liked": isLiked
        ])
    }

    static func previewSaved(surface: MapAnalyticsSurface, spotId: String?, isSaved: Bool) {
        AnalyticsService.shared.logEvent("map_preview_saved", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil",
            "is_saved": isSaved
        ])
    }

    static func previewOpened(surface: MapAnalyticsSurface, spotId: String?) {
        AnalyticsService.shared.logEvent("map_preview_opened", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil"
        ])
    }

    static func previewDismissed(surface: MapAnalyticsSurface, spotId: String?, reason: String) {
        AnalyticsService.shared.logEvent("map_preview_dismissed", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil",
            "reason": reason
        ])
    }

    static func filterChanged(dimensions: [String]) {
        AnalyticsService.shared.logEvent("map_filter_changed", parameters: [
            "dimensions": dimensions.joined(separator: ",")
        ])
    }

    static func recenterTapped() {
        AnalyticsService.shared.logEvent("map_recenter_tapped", parameters: nil)
    }
}
