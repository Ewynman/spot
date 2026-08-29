//
//  MapOverlapResolver.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import CoreLocation

/// Resolves coordinate collisions for a slice of spots.
///
/// Spots whose lat/lon round to the same `bucketSize` cell are treated as
/// overlapping and pushed onto a small ring around their shared centroid.
/// The first spot stays at the centroid; subsequent spots are placed on a
/// ring with `offsetMeters` radius. Ring placement is deterministic on
/// `spot.id` so the same input always produces the same offsets.
struct MapOverlapResolver {

    private let bucketSize: Double
    private let offsetMeters: Double

    init(
        bucketSize: Double = Constants.MapDesign.overlapBucketSize,
        offsetMeters: Double = Constants.MapDesign.overlapOffsetMeters
    ) {
        self.bucketSize = bucketSize
        self.offsetMeters = offsetMeters
    }

    /// Returns an array of `(spot, resolvedCoordinate)` tuples in stable
    /// order. Spots without coordinates are dropped.
    func resolve(_ spots: [Spot]) -> [(spot: Spot, coordinate: CLLocationCoordinate2D)] {
        // Bucket by quantized coordinate.
        var buckets: [String: [(Spot, CLLocationCoordinate2D)]] = [:]
        var bucketOrder: [String] = []
        for s in spots {
            guard let lat = s.latitude, let lon = s.longitude else { continue }
            let key = bucketKey(lat: lat, lon: lon)
            let entry = (s, CLLocationCoordinate2D(latitude: lat, longitude: lon))
            if buckets[key] == nil {
                bucketOrder.append(key)
                buckets[key] = [entry]
            } else {
                buckets[key]?.append(entry)
            }
        }

        // For each bucket, fan members out around the centroid.
        var resolved: [(spot: Spot, coordinate: CLLocationCoordinate2D)] = []
        resolved.reserveCapacity(spots.count)
        for key in bucketOrder {
            guard let members = buckets[key], !members.isEmpty else { continue }
            if members.count == 1 {
                resolved.append((members[0].0, members[0].1))
                continue
            }
            let centroid = centroidOf(members.map { $0.1 })
            // Sort within the bucket so the "anchor" pin is deterministic
            // (smallest id wins). Subsequent members go on a ring.
            let sorted = members.sorted { lhs, rhs in
                (lhs.0.id ?? "") < (rhs.0.id ?? "")
            }
            for (index, member) in sorted.enumerated() {
                if index == 0 {
                    resolved.append((member.0, centroid))
                    continue
                }
                let offset = ringOffset(
                    indexInBucket: index,
                    bucketSize: sorted.count,
                    radiusMeters: offsetMeters,
                    centroidLat: centroid.latitude
                )
                let newCoord = CLLocationCoordinate2D(
                    latitude: centroid.latitude + offset.dLat,
                    longitude: centroid.longitude + offset.dLon
                )
                resolved.append((member.0, newCoord))
            }
        }
        return resolved
    }

    /// Returns the bucket count, useful for `MapMarkerLogs.overlapBucketResolved`.
    func bucketStats(_ spots: [Spot]) -> (totalBuckets: Int, multiBuckets: Int, maxMembers: Int) {
        var buckets: [String: Int] = [:]
        for s in spots {
            guard let lat = s.latitude, let lon = s.longitude else { continue }
            let key = bucketKey(lat: lat, lon: lon)
            buckets[key, default: 0] += 1
        }
        let multi = buckets.values.filter { $0 > 1 }
        return (buckets.count, multi.count, buckets.values.max() ?? 0)
    }

    // MARK: - Internals

    private func bucketKey(lat: Double, lon: Double) -> String {
        let qLat = (lat / bucketSize).rounded() * bucketSize
        let qLon = (lon / bucketSize).rounded() * bucketSize
        // Use printf to avoid hash drift on floating-point printing differences.
        return String(format: "%.6f,%.6f", qLat, qLon)
    }

    private func centroidOf(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else { return CLLocationCoordinate2D(latitude: 0, longitude: 0) }
        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Convert `radiusMeters` at a given latitude into a (Δlat, Δlon) pair
    /// on a ring. `index 1...N-1` are evenly spaced around 360°.
    private func ringOffset(
        indexInBucket: Int,
        bucketSize: Int,
        radiusMeters: Double,
        centroidLat: Double
    ) -> (dLat: Double, dLon: Double) {
        let memberCount = max(1, bucketSize - 1)
        let theta = (Double(indexInBucket - 1) / Double(memberCount)) * 2.0 * .pi
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(centroidLat * .pi / 180.0)
        let dLat = (radiusMeters * sin(theta)) / metersPerDegLat
        let dLon = (radiusMeters * cos(theta)) / max(metersPerDegLon, 1)
        return (dLat, dLon)
    }
}
