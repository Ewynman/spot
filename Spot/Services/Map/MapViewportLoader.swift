//
//  MapViewportLoader.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import MapKit

/// Loads map spots for a viewport via `public.get_map_spots_v1` (PostGIS).
/// Server applies the same privacy/blocking rules as the home feed; the client
/// signs primary images only.
actor MapViewportLoader {
    static let shared = MapViewportLoader()

    private var viewportCache: [String: ([Spot], Date)] = [:]
    private var viewportLRU: [String] = []
    private let maxCachedViewports = 32
    private let viewportCacheTTL: TimeInterval = 60

    func clearCache() {
        viewportCache.removeAll()
        viewportLRU.removeAll()
    }

    /// Fetches map spots for the given region. Returned `Spot`s carry only a
    /// primary image URL — full image arrays are lazily loaded on detail.
    func load(region: MKCoordinateRegion, perTileLimit: Int = 200) async -> [Spot] {
        await loadFromRPC(region: region, limit: perTileLimit)
    }

    private func loadFromRPC(region: MKCoordinateRegion, limit: Int) async -> [Spot] {
        let bbox = boundingBox(for: region)
        let cacheKey = quantizedViewportKey(bbox)
        if let cached = viewportCache[cacheKey],
           Date().timeIntervalSince(cached.1) < viewportCacheTTL {
            return cached.0
        }

        do {
            let rows = try await FeedAPI.fetchMapSpots(
                minLat: bbox.minLat,
                minLng: bbox.minLng,
                maxLat: bbox.maxLat,
                maxLng: bbox.maxLng,
                centerLat: region.center.latitude,
                centerLng: region.center.longitude,
                limit: limit
            )

            let urlMap = await FeedAPI.resolvePrimaryImageURLs(for: rows)
            let hydrated = rows.map { $0.toSpot(primaryURL: urlMap[$0.spotId]) }

            viewportCache[cacheKey] = (hydrated, Date())
            viewportLRU.removeAll { $0 == cacheKey }
            viewportLRU.append(cacheKey)
            evictViewportIfNeeded()
            return hydrated
        } catch is CancellationError {
            return []
        } catch {
            let nsError = error as NSError
            let isCancellation =
                (nsError.code == NSURLErrorCancelled) ||
                ((error as? URLError)?.code == .cancelled) ||
                error.localizedDescription.lowercased().contains("cancelled")
            if isCancellation {
                return []
            }
            SpotLogger.log(FeedSupabaseLogs.mapRPCFailed, details: ["error": error.localizedDescription])
            return []
        }
    }

    private struct BoundingBox {
        let minLat: Double
        let minLng: Double
        let maxLat: Double
        let maxLng: Double
    }

    private func boundingBox(for region: MKCoordinateRegion) -> BoundingBox {
        let halfLat = max(region.span.latitudeDelta / 2.0, 0.001)
        let halfLng = max(region.span.longitudeDelta / 2.0, 0.001)
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLng = region.center.longitude - halfLng
        let maxLng = region.center.longitude + halfLng
        return BoundingBox(
            minLat: max(-90, minLat),
            minLng: max(-180, minLng),
            maxLat: min(90, maxLat),
            maxLng: min(180, maxLng)
        )
    }

    private func quantizedViewportKey(_ bbox: BoundingBox) -> String {
        let span = max(bbox.maxLat - bbox.minLat, bbox.maxLng - bbox.minLng)
        let step: Double
        if span > 5 { step = 1.0 }
        else if span > 1 { step = 0.25 }
        else if span > 0.25 { step = 0.05 }
        else if span > 0.06 { step = 0.01 }
        else { step = 0.0025 }

        func q(_ x: Double) -> Double {
            (x / step).rounded() * step
        }
        return "\(q(bbox.minLat)),\(q(bbox.minLng)),\(q(bbox.maxLat)),\(q(bbox.maxLng))"
    }

    private func evictViewportIfNeeded() {
        while viewportLRU.count > maxCachedViewports {
            let key = viewportLRU.removeFirst()
            viewportCache.removeValue(forKey: key)
        }
    }
}
