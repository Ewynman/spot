//
//  FeedEventService.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Engagement event types accepted by `public.feed_event_weight_v1`.
///
/// These map directly to the Postgres weighting table; adding a new type here
/// without adding a weight server-side is fine but the event won't influence
/// affinities until a weight is assigned.
enum FeedEventType: String, Sendable {
    case impression                // Card became visible in the feed (raw, near-zero weight)
    case visible2s       = "visible_2s"   // Cell crossed the 2s visible threshold
    case longDwell       = "long_dwell"   // Cell was visible for 8s+ before leaving
    case detailOpen      = "detail_open"  // User opened the spot detail panel/page
    case quickSkip       = "quick_skip"   // Cell left viewport in <1s after appearing
    case like
    case unlike
    case save
    case unsave
    case share
    case profileTap      = "profile_tap"
    case vibeTap         = "vibe_tap"
    case mapPinTap       = "map_pin_tap"
    case hide                          // user hid this spot
    case reportAuthor    = "report"
    case blockAuthor     = "block_author"
    case followAuthor    = "follow_author"
    case unfollowAuthor  = "unfollow_author"
}

/// Wraps `record_feed_event_v1` calls. Stateful so it can debounce rapid
/// `impression` events (a single scroll can fire dozens of `onAppear`
/// callbacks in <1s) and maintain dwell timers per-spot.
actor FeedEventService {
    static let shared = FeedEventService()

    /// Minimum interval (seconds) between consecutive `impression` events for
    /// the same spot. Avoids re-recording when the same cell oscillates in/out
    /// of the viewport during a scroll.
    private let impressionDebounceInterval: TimeInterval = 30

    /// Tracks the wall-clock time the spot first appeared in the viewport,
    /// used to compute dwell on disappearance.
    private var visibilityStartedAt: [UUID: Date] = [:]

    /// Last time we emitted an `impression` event for a spot.
    private var lastImpressionAt: [UUID: Date] = [:]

    /// Spots for which the 2-second visibility threshold has already fired in
    /// this session. Prevents duplicate `visible_2s` events when the cell
    /// re-enters the viewport.
    private var visible2sFired: Set<UUID> = []

    /// Per-spot scheduled tasks responsible for firing the 2s threshold.
    /// Stored so we can cancel them if the cell disappears before 2s.
    private var visible2sTasks: [UUID: Task<Void, Never>] = [:]

    /// Threshold in seconds before we fire `visible_2s`. Matches the server
    /// weight table.
    private let visible2sThreshold: TimeInterval = 2.0

    /// Threshold in seconds before we fire `long_dwell` on disappear. Matches
    /// the server weight table.
    private let longDwellThreshold: TimeInterval = 8.0

    /// Anything below this is treated as a noisy `quick_skip` (negative
    /// signal: user scrolled past without engaging).
    private let quickSkipThreshold: TimeInterval = 1.0

    private init() {}

    // MARK: - Visibility / dwell tracking (sync entry points)

    /// View-friendly convenience: routes an `onAppear` for a feed cell into
    /// the actor without making the call site `async`.
    nonisolated static func recordImpression(spot: Spot) {
        guard let raw = spot.id, let uuid = UUID(uuidString: raw) else { return }
        Task.detached { await shared.cellDidAppear(spotId: uuid) }
    }

    /// View-friendly convenience: routes an `onDisappear` for a feed cell
    /// into the actor without making the call site `async`.
    nonisolated static func recordCellLeftViewport(spot: Spot) {
        guard let raw = spot.id, let uuid = UUID(uuidString: raw) else { return }
        Task.detached { await shared.cellDidDisappear(spotId: uuid) }
    }

    /// Notify the service that a feed cell became visible. Records an
    /// `impression` event (debounced) and starts a dwell timer. Also schedules
    /// a `visible_2s` event after the configured threshold if the cell stays
    /// in view that long.
    func cellDidAppear(spotId: UUID) {
        let now = Date()
        visibilityStartedAt[spotId] = now

        if let last = lastImpressionAt[spotId],
           now.timeIntervalSince(last) < impressionDebounceInterval {
            SpotLogger.log(FeedEventServiceLogs.visibilityDebounced, details: [
                "spotId": spotId.uuidString,
                "secondsSinceLast": now.timeIntervalSince(last)
            ])
        } else {
            lastImpressionAt[spotId] = now
            Task.detached { [spotId] in
                await Self.fireAndForget(.impression, spotId: spotId, dwellMs: nil)
            }
        }

        if !visible2sFired.contains(spotId) {
            visible2sTasks[spotId]?.cancel()
            let threshold = visible2sThreshold
            visible2sTasks[spotId] = Task { [weak self, spotId, threshold] in
                let nanos = UInt64(threshold * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled else { return }
                await self?.fireVisible2sIfStillVisible(spotId: spotId)
            }
        }
    }

    /// Internal: invoked by the scheduled task when the visible-2s threshold
    /// elapses. Fires the event only if the cell is still visible and the
    /// event hasn't already been emitted for this spot in the session.
    private func fireVisible2sIfStillVisible(spotId: UUID) {
        visible2sTasks[spotId] = nil
        guard let start = visibilityStartedAt[spotId] else { return }
        guard !visible2sFired.contains(spotId) else { return }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed >= visible2sThreshold else { return }
        visible2sFired.insert(spotId)
        Task.detached { [spotId, elapsed] in
            await Self.fireAndForget(
                .visible2s,
                spotId: spotId,
                dwellMs: Int(elapsed * 1000)
            )
        }
    }

    /// Notify the service that a feed cell left the viewport. Emits one of:
    ///  * `quick_skip` if the cell was visible for <1s (negative signal),
    ///  * `long_dwell` if the cell was visible for ≥8s (strong positive),
    ///  * nothing otherwise (the visible_2s event already covered moderate
    ///    engagement).
    func cellDidDisappear(spotId: UUID) {
        visible2sTasks[spotId]?.cancel()
        visible2sTasks[spotId] = nil
        guard let start = visibilityStartedAt.removeValue(forKey: spotId) else { return }
        let dwellSeconds = Date().timeIntervalSince(start)
        let dwellMs = Int(dwellSeconds * 1000)
        if dwellSeconds >= longDwellThreshold {
            Task.detached { [spotId, dwellMs] in
                await Self.fireAndForget(.longDwell, spotId: spotId, dwellMs: dwellMs)
            }
        } else if dwellSeconds < quickSkipThreshold {
            Task.detached { [spotId, dwellMs] in
                await Self.fireAndForget(.quickSkip, spotId: spotId, dwellMs: dwellMs)
            }
        }
    }

    /// Reset all visibility/dwell state. Call on sign-out or when a fresh
    /// feed is loaded so stale state from a previous session can't leak in.
    func reset() {
        for (_, task) in visible2sTasks { task.cancel() }
        visible2sTasks.removeAll()
        visible2sFired.removeAll()
        visibilityStartedAt.removeAll()
        lastImpressionAt.removeAll()
    }

    // MARK: - One-off events

    /// Records a non-visibility event (`like`, `save`, `share`, etc.).
    /// Fire-and-forget by design — the UI never blocks on personalization
    /// telemetry, and the server is authoritative if a write is lost.
    nonisolated static func record(
        _ event: FeedEventType,
        spotId: UUID,
        dwellMs: Int? = nil,
        metadata: [String: Any]? = nil
    ) {
        Task.detached {
            await fireAndForget(event, spotId: spotId, dwellMs: dwellMs, metadata: metadata)
        }
    }

    /// Convenience: accepts a string `spotId` (UI models hold these as
    /// strings) and silently no-ops on invalid UUIDs.
    nonisolated static func record(
        _ event: FeedEventType,
        spotId: String?,
        dwellMs: Int? = nil,
        metadata: [String: Any]? = nil
    ) {
        guard let raw = spotId, let uuid = UUID(uuidString: raw) else { return }
        record(event, spotId: uuid, dwellMs: dwellMs, metadata: metadata)
    }

    // MARK: - RPC

    private static func fireAndForget(
        _ event: FeedEventType,
        spotId: UUID,
        dwellMs: Int?,
        metadata: [String: Any]? = nil
    ) async {
        struct Params: Encodable {
            let p_spot_id: String
            let p_event_type: String
            let p_dwell_ms: Int?
            let p_metadata: [String: AnyEncodable]?
        }

        let encodedMetadata: [String: AnyEncodable]? = metadata.map { dict in
            dict.reduce(into: [String: AnyEncodable]()) { acc, pair in
                acc[pair.key] = AnyEncodable(pair.value)
            }
        }

        let params = Params(
            p_spot_id: spotId.uuidString.lowercased(),
            p_event_type: event.rawValue,
            p_dwell_ms: dwellMs,
            p_metadata: encodedMetadata
        )

        do {
            _ = try await supabase
                .rpc("record_feed_event_v1", params: params)
                .execute()
            SpotLogger.log(FeedEventServiceLogs.eventRecorded, details: [
                "event": event.rawValue,
                "spotId": spotId.uuidString,
                "dwellMs": dwellMs ?? -1
            ])
        } catch {
            SpotLogger.log(FeedEventServiceLogs.eventFailed, details: [
                "event": event.rawValue,
                "spotId": spotId.uuidString,
                "error": error.localizedDescription
            ])
        }
    }
}

/// Minimal type-erased `Encodable` so callers can pass heterogenous metadata
/// dicts without writing a custom struct per event type. Supports the JSON
/// primitive value types we actually emit; falls back to `String(describing:)`.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: Any) {
        switch value {
        case let v as String:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case let v as Bool:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case let v as Int:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case let v as Int64:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case let v as Double:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case let v as [String]:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case let v as [Int]:
            self._encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case is NSNull:
            self._encode = { var c = $0.singleValueContainer(); try c.encodeNil() }
        default:
            let s = String(describing: value)
            self._encode = { var c = $0.singleValueContainer(); try c.encode(s) }
        }
    }

    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
