//
//  FeedRanker.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import CoreLocation

/// Simple on-device ranker and blender.
/// - Pool A: recent (time decay)
/// - Pool C: trending (uses trendingScore if present)
/// Blends A:C with fixed ratio and removes duplicates.
final class FeedRanker {
    static let shared = FeedRanker()
    private init() {}

    // MVP weights confirmed by user
    private let wVibe: Double = 0.45
    private let wFresh: Double = 0.25
    private let wAffinity: Double = 0.20
    private let wDistance: Double = 0.10
    private let tauHours: Double = 72.0
    private let nearKm: Double = 25.0

    struct Context {
        let followeeIds: Set<String>
        let userVibeStats: [String: Int]
        let userLocation: CLLocation?
        let seenSpotIds: Set<String>
    }

    func score(_ spot: Spot, ctx: Context) -> Double {
        // vibe — Dirichlet-style smoothing so a single liked tag cannot dominate
        // the weighted sum for low-signal preference vectors.
        let total = max(1, ctx.userVibeStats.values.reduce(0, +))
        let vibeCount = ctx.userVibeStats[spot.vibeTag ?? ""] ?? 0
        let distinctTags = max(ctx.userVibeStats.count, 1)
        let k = max(distinctTags, 4)
        let alpha = 2.0
        let vibe = (Double(vibeCount) + alpha) / (Double(total) + alpha * Double(k))

        // freshness exp decay
        let ageH = max(0.0, -(spot.createdAt ?? .distantPast).timeIntervalSinceNow / 3600.0)
        let fresh = exp(-ageH / tauHours)

        // affinity (MVP): 1 if followee, else 0
        let affinity = ctx.followeeIds.contains(spot.userId ?? "") ? 1.0 : 0.0

        // distance (MVP): normalize to [0,1]; 1 if within nearKm; else decays
        var distScore = 0.0
        if let userLoc = ctx.userLocation, let lat = spot.latitude, let lon = spot.longitude {
            let dKm = userLoc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000.0
            if dKm <= nearKm { distScore = 1.0 } else { distScore = max(0.0, nearKm / dKm) }
        }

        return wVibe*vibe + wFresh*fresh + wAffinity*affinity + wDistance*distScore
    }

    func blend(followees: [Spot], global: [Spot], pageSize: Int, creatorCap: Int = 2) -> [Spot] {
        let fTarget = pageSize / 2
        let gTarget = pageSize - fTarget
        var picked: [Spot] = []
        var seenKeys = Set<String>()
        var perCreator: [String: Int] = [:]

        func push(_ s: Spot, enforceCreatorCap: Bool) {
            // Build a robust key so we don't drop items if id is temporarily nil
            let key: String = {
                if let id = s.id { return "id:\(id)" }
                let uid = s.userId ?? "_"
                let ts = s.createdAt?.timeIntervalSince1970 ?? 0
                return "u:\(uid)#t:\(ts)"
            }()
            guard !seenKeys.contains(key) else {
                FeedDiagnostics.logExclusion(reason: "blend_seen", source: "FeedRanker.blend", spot: s)
                return
            }
            // creator cap
            let author = s.userId ?? "_"
            if enforceCreatorCap && (perCreator[author] ?? 0) >= creatorCap { return }
            picked.append(s)
            seenKeys.insert(key)
            perCreator[author] = (perCreator[author] ?? 0) + 1
        }

        for s in followees.prefix(fTarget) { push(s, enforceCreatorCap: true) }
        for s in global.prefix(gTarget) { push(s, enforceCreatorCap: true) }

        // Backfill if underfilled
        if picked.count < pageSize {
            for s in followees where picked.count < pageSize { push(s, enforceCreatorCap: true) }
            for s in global where picked.count < pageSize { push(s, enforceCreatorCap: true) }
        }

        // Final safety backfill: if still underfilled (e.g. one creator dominates),
        // relax creator cap so we still return a full page.
        if picked.count < pageSize {
            for s in followees where picked.count < pageSize { push(s, enforceCreatorCap: false) }
            for s in global where picked.count < pageSize { push(s, enforceCreatorCap: false) }
        }

        return picked
    }
}
