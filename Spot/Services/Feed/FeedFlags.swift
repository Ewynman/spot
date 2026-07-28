//
//  FeedFlags.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import Foundation

/// Runtime flags to control feed behavior and diagnostics
struct FeedFlags {
    /// Disable any persistent deduplication across app sessions
    static var disablePersistentDedupe: Bool = false

    /// Comprehensive feed diagnostics are part of profile 4 only.
    static var enableDiagnosticLogging: Bool {
        SpotLogger.profile == .all
    }

    /// TTL for persistent seen tracking (in hours, 0 = disabled)
    static var persistentSeenTTL: TimeInterval = 24 * 7 // 7 days

    /// Unified page size across all feed components
    static let pageSize: Int = 24

    // MARK: - V2 home feed (Supabase RPC + durable impressions)

    /// When true, only the primary image for each returned feed row is hydrated
    /// (signed) by the home feed path. Full image arrays are loaded lazily in
    /// detail views. Avoids signing N images for every candidate.
    static var hydrateOnlyPrimaryFeedImage: Bool = true

    /// When true, treats `feed_impressions` as the authoritative seen state and
    /// keeps `UserDefaults`-based seen only as a transient local safety net.
    static var useServerSideImpressions: Bool = true

}

/// Feed diagnostic logging
struct FeedDiagnostics {
    static func logExclusion(reason: String, source: String, spot: Spot) {
        guard FeedFlags.enableDiagnosticLogging else { return }

        SpotLogger.log(FeedFlagsLogs.feedExclusion, details: [
            "reason": reason,
            "source": source,
            "spotId": spot.safeId,
            "createdAt": spot.createdAt?.description ?? "nil",
            "likes": spot.likes ?? 0,
            "username": spot.username ?? "nil"
        ])
    }

    static func logFeedStats(recentCount: Int, trendingCount: Int, nilIdCount: Int, excludedByPersistentSeen: Int, excludedByBlendSeen: Int, excludedByExistingIds: Int) {
        guard FeedFlags.enableDiagnosticLogging else { return }

        SpotLogger.log(FeedFlagsLogs.feedStats, details: [
            "recent": recentCount,
            "trending": trendingCount,
            "nilId": nilIdCount,
            "excludedByPersistentSeen": excludedByPersistentSeen,
            "excludedByBlendSeen": excludedByBlendSeen,
            "excludedByExistingIds": excludedByExistingIds
        ])
    }

    static func logColdStart(seenSetSize: Int, isApplied: Bool) {
        guard FeedFlags.enableDiagnosticLogging else { return }

        SpotLogger.log(FeedFlagsLogs.feedColdStart, details: [
            "seenSetSize": seenSetSize,
            "isApplied": isApplied,
            "disablePersistentDedupe": FeedFlags.disablePersistentDedupe
        ])
    }
}
