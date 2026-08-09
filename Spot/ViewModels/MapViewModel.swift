//
//  MapViewModel.swift
//  Spot
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Foundation
import MapKit
import CoreLocation

@MainActor
final class MapViewModel: ObservableObject {
    @Published var visibleSpots: [Spot] = []
    @Published var isLoadingAllSpots: Bool = false

    private var regionLoadTask: Task<Void, Never>?
    private let regionDebounceNs: UInt64 = 250_000_000 // 250ms

    /// Last region used for fetching, retained so the trim step can
    /// prioritise spots near the viewport center after a merge.
    private var lastFetchRegion: MKCoordinateRegion?

    /// No-op: map spots load per viewport via `loadForRegion` + `get_map_spots_v1`.
    func loadAllSpots() {}

    /// Load spots for the visible viewport. Debounced — rapid pan/zoom emits
    /// many region-change callbacks but we only refetch once the region has
    /// settled for ~250ms. After fetch, the merged set is *trimmed* so it
    /// can never grow unbounded across long pan sessions (PRD §8 risk).
    func loadForRegion(_ region: MKCoordinateRegion, limit: Int = 250) {
        regionLoadTask?.cancel()
        SpotLogger.log(MapViewModelLogs.viewportFetchStarted, details: [
            "centerLat": region.center.latitude,
            "centerLng": region.center.longitude,
            "spanLat": region.span.latitudeDelta,
            "spanLng": region.span.longitudeDelta
        ])
        regionLoadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.regionDebounceNs ?? 250_000_000)
            if Task.isCancelled {
                SpotLogger.log(MapViewModelLogs.viewportFetchCancelled)
                return
            }
            guard let self else { return }
            self.isLoadingAllSpots = true
            self.lastFetchRegion = region
            let spots = await MapViewportLoader.shared.load(region: region, perTileLimit: limit)
            if Task.isCancelled {
                SpotLogger.log(MapViewModelLogs.viewportFetchCancelled)
                return
            }
            let merged = Self.mergeRetainingExisting(current: self.visibleSpots, fresh: spots)
            let trimmed = Self.trim(merged,
                                    near: region.center,
                                    cap: Constants.MapDesign.visibleSpotsCap)
            if trimmed.count < merged.count {
                SpotLogger.log(MapViewModelLogs.visibleSpotsTrimmed, details: [
                    "before": merged.count,
                    "after": trimmed.count,
                    "cap": Constants.MapDesign.visibleSpotsCap
                ])
            }
            self.visibleSpots = trimmed
            self.isLoadingAllSpots = false
            SpotLogger.log(MapViewModelLogs.viewportFetchFinished, details: [
                "fetched": spots.count,
                "merged": merged.count,
                "visible": trimmed.count
            ])
            SpotLogger.log(MapViewModelLogs.visibleSpotsMerged, details: ["count": trimmed.count])
        }
    }

    /// Merges the freshly-loaded viewport with what's already on screen, so
    /// pinning out of the viewport for a moment doesn't make pins disappear
    /// and reappear. Newly-fetched rows always win on conflict (their primary
    /// URLs may be newer signed values).
    nonisolated static func mergeRetainingExisting(current: [Spot], fresh: [Spot]) -> [Spot] {
        var byId: [String: Spot] = [:]
        var order: [String] = []
        for s in current {
            if let id = s.id {
                if byId[id] == nil { order.append(id) }
                byId[id] = s
            }
        }
        for s in fresh {
            if let id = s.id {
                if byId[id] == nil { order.append(id) }
                byId[id] = s
            }
        }
        return order.compactMap { byId[$0] }
    }

    /// Trim a merged spot list down to `cap` items, prioritising spots that
    /// are nearest to `center`. Keeps `MapViewModel.visibleSpots` from
    /// accumulating across long pan sessions (PRD §8 acceptance: "Panning
    /// across several regions does not grow `visibleSpots` indefinitely.").
    nonisolated static func trim(_ spots: [Spot],
                                 near center: CLLocationCoordinate2D,
                                 cap: Int) -> [Spot] {
        guard cap > 0 else { return [] }
        if spots.count <= cap { return spots }
        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let withDistance: [(Spot, Double)] = spots.map { spot in
            guard let lat = spot.latitude, let lon = spot.longitude else {
                return (spot, .greatestFiniteMagnitude)
            }
            let d = centerLoc.distance(from: CLLocation(latitude: lat, longitude: lon))
            return (spot, d)
        }
        let sorted = withDistance.sorted { $0.1 < $1.1 }
        return sorted.prefix(cap).map { $0.0 }
    }

    func clearVisibleSpots() {
        regionLoadTask?.cancel()
        visibleSpots.removeAll(keepingCapacity: false)
        lastFetchRegion = nil
    }

    func locallyReplaceSpot(_ spot: Spot) {
        guard let index = visibleSpots.firstIndex(where: { $0.id == spot.id }) else { return }
        visibleSpots[index] = spot
    }
}
