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

@MainActor
enum MapAnalytics {
    static func markerTapped(surface: MapAnalyticsSurface, spotId: String?) {
        AnalyticsService.shared.logEvent("map_marker_tapped", parameters: [
            "surface": surface.rawValue,
            "spot_id": spotId ?? "nil"
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
