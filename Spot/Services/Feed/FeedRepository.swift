//
//  FeedRepository.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import CoreLocation

/// Coarse load state for the homepage feed. Distinct from "is `spots` empty?"
/// because we want to keep the existing list visible during retries and show
/// targeted empty/error overlays only when there is genuinely nothing to show.
enum FeedLoadState: Equatable {
    case idle
    case loadingInitial
    case loadingMore
    case loaded
    /// No items to show, with the reason returned from `get_home_feed_status_v1`.
    case empty(reason: String)
    /// Last load attempt failed. The repository keeps any previously-loaded
    /// spots in `spots` so the UI can show them while the user retries.
    case error(message: String)
}

final class FeedRepository: ObservableObject {
    static let shared = FeedRepository()
    private init() {}

    // MARK: - Published

    @Published private(set) var spots: [Spot] = []
    @Published private(set) var loadState: FeedLoadState = .idle
    /// Latest empty/diagnostic status from `get_home_feed_status_v1`. Used by
    /// the UI to vary the empty-state copy (caught up vs. nothing visible
    /// vs. truly no content).
    @Published private(set) var emptyStatus: HomeFeedStatus? = nil
    /// Surfaced to the UI as a non-blocking toast when a refresh fails after
    /// initial content has been displayed. Cleared on next successful load.
    @Published private(set) var refreshErrorMessage: String? = nil

    // MARK: - State

    /// Whether the next call to `loadMore()` is expected to return new rows.
    /// Set to false only when the server returned 0 rows AND a follow-up
    /// status check confirmed no eligible content exists.
    private(set) var moreAvailable: Bool = true

    /// Number of consecutive `loadMore()` calls that returned 0 new rows.
    /// Used to stop infinite-scroll spam against an exhausted feed.
    private var consecutiveEmptyLoadMore = 0

    private let pageSize = FeedFlags.pageSize

    // MARK: - Public API

    func loadInitial() async {
        await loadInitialV2()
    }

    func loadMore() async {
        await loadMoreV2()
    }

    /// Marks a spot as locally hidden (matches `user_hidden_spots`) and removes
    /// it from the in-memory feed. Useful when the user invokes a "Not
    /// interested" action, since the row will be filtered out server-side on
    /// the next refresh.
    @MainActor
    func locallyRemoveSpot(id: String) {
        spots.removeAll { $0.id == id }
        if spots.isEmpty {
            loadState = .empty(reason: emptyStatus?.status ?? "caught_up")
        }
    }

    /// Removes every in-memory spot whose `userId` matches (e.g. after blocking the author).
    @MainActor
    func locallyRemoveSpotsFromAuthor(userId: String) {
        spots.removeAll { $0.userId == userId }
        if spots.isEmpty {
            loadState = .empty(reason: emptyStatus?.status ?? "caught_up")
        }
    }

    /// Inserts a freshly-posted spot at the top of the feed without a refresh.
    /// Intended only for the post-publish flow where the new row hasn't yet
    /// propagated to `get_home_feed_v1` results.
    @MainActor
    func insertSpotAtTop(_ spot: Spot) {
        spots.removeAll { $0.id == spot.id }
        spots.insert(spot, at: 0)
        loadState = .loaded
        emptyStatus = nil
    }

    @MainActor
    func locallyReplaceSpot(_ spot: Spot) {
        guard let index = spots.firstIndex(where: { $0.id == spot.id }) else { return }
        spots[index] = spot
    }

    /// Replaces the current in-memory feed wholesale. Used to roll back an
    /// optimistic delete when the server write fails.
    @MainActor
    func replaceSpots(_ next: [Spot]) {
        spots = next
        loadState = next.isEmpty ? .empty(reason: emptyStatus?.status ?? "caught_up") : .loaded
    }

    /// Clears any in-memory state. Call on sign-out so a different user
    /// doesn't inherit the previous user's feed.
    @MainActor
    func reset() {
        spots = []
        loadState = .idle
        emptyStatus = nil
        refreshErrorMessage = nil
        moreAvailable = true
        consecutiveEmptyLoadMore = 0
    }

    // MARK: - V2 path

    private func loadInitialV2() async {
        PerfMetrics.shared.mark("t_first_item")

        let hadExistingSpots = await MainActor.run { !self.spots.isEmpty }
        await MainActor.run {
            self.loadState = .loadingInitial
            self.refreshErrorMessage = nil
        }

        let location = await currentUserLocation()
        do {
            async let optionalFeedProfile = Self.loadOptionalFeedProfileSnapshot()
            let firstAttempt = try await FeedAPI.fetchHomeFeed(
                limit: pageSize,
                viewerLatitude: location?.coordinate.latitude,
                viewerLongitude: location?.coordinate.longitude,
                forceSeenFallback: false
            )

            // Auto-fallback: if there is no unseen content but the user does
            // have eligible content (status = caught_up), re-run the RPC with
            // forceSeenFallback=true rather than showing the empty state.
            // The seen-fallback bucket re-ranks already-seen rows by least
            // recently shown, so the user keeps getting fresh-feeling content.
            let initialFallbackStatus: HomeFeedStatus?
            let secondAttempt: [HomeFeedRow]
            if firstAttempt.isEmpty {
                let status = try? await FeedAPI.fetchHomeFeedStatus()
                initialFallbackStatus = status
                if status?.status == "caught_up" {
                    SpotLogger.log(FeedSupabaseLogs.loadInitialAutoFallback, details: [
                        "reason": "caught_up_with_eligible_seen",
                        "eligible": status?.eligibleSpots ?? -1
                    ])
                    secondAttempt = (try? await FeedAPI.fetchHomeFeed(
                        limit: pageSize,
                        viewerLatitude: location?.coordinate.latitude,
                        viewerLongitude: location?.coordinate.longitude,
                        forceSeenFallback: true
                    )) ?? []
                } else {
                    secondAttempt = []
                }
            } else {
                initialFallbackStatus = nil
                secondAttempt = []
            }

            let rows = firstAttempt.isEmpty ? secondAttempt : firstAttempt
            let usedSeenFallback = rows.contains { $0.sourceBucket == "seen_fallback" }

            if usedSeenFallback {
                SpotLogger.log(FeedSupabaseLogs.loadInitialUsedSeenFallback, details: [
                    "rows": rows.count
                ])
            }

            var hydrated = await hydrateRows(rows)
            let feedProfileRow = await optionalFeedProfile
            let diversity = FeedDiversity.diversifyHomeFeedPage(hydrated, feedProfileRow: feedProfileRow)
            hydrated = diversity.spots
            let m = diversity.metrics
            SpotLogger.log(FeedRepositoryLogs.diversityPassApplied, details: [
                "userSignalCount": m.userSignalCount,
                "lowSignalMode": m.lowSignalMode,
                "inputCount": m.inputCount,
                "distinctTagsFirst10": m.distinctTagsInFirstWindow,
                "maxSameTagFirst10": m.maxTagRepeatsInFirstWindow,
                "maxSameCreatorFirst10": m.maxCreatorRepeatsInFirstWindow,
                "reorderMoves": m.reorderMoves
            ])

            if hydrated.isEmpty {
                let resolvedStatus: HomeFeedStatus?
                if let initialFallbackStatus {
                    resolvedStatus = initialFallbackStatus
                } else {
                    resolvedStatus = try? await FeedAPI.fetchHomeFeedStatus()
                }
                let status = resolvedStatus
                let emptyReason = status?.status ?? "no_eligible_spots"
                await MainActor.run {
                    self.spots = []
                    self.emptyStatus = status
                    self.loadState = .empty(reason: emptyReason)
                    self.moreAvailable = false
                }
                return
            }

            let rowCount = rows.count
            let pageSizeSnapshot = self.pageSize
            await MainActor.run {
                self.spots = hydrated
                self.emptyStatus = nil
                self.loadState = .loaded
                self.moreAvailable = !usedSeenFallback || rowCount == pageSizeSnapshot
                self.consecutiveEmptyLoadMore = 0
            }

            SpotLogger.log(FeedRepositoryLogs.loadInitial, details: [
                "rows": rows.count,
                "hydrated": hydrated.count,
                "usedSeenFallback": usedSeenFallback
            ])
        } catch is CancellationError {
            SpotLogger.log(FeedRepositoryLogs.loadInitialFailed, details: ["error": "cancelled"])
            // Don't touch published state on cancellation; another refresh is
            // already in flight.
        } catch {
            SpotLogger.log(FeedRepositoryLogs.loadInitialFailed, details: ["error": error.localizedDescription])
            SpotLogger.log(FeedSupabaseLogs.rpcFailed, details: [
                "phase": "loadInitial",
                "preserveOldContent": hadExistingSpots,
                "error": error.localizedDescription
            ])
            await MainActor.run {
                if hadExistingSpots {
                    self.refreshErrorMessage = "Couldn't refresh your feed. Showing previous spots."
                    self.loadState = .loaded
                    SpotLogger.log(FeedSupabaseLogs.loadInitialPreserveOldContent, details: [
                        "remaining": self.spots.count
                    ])
                } else {
                    self.loadState = .error(message: error.localizedDescription)
                }
            }
        }
    }

    private func loadMoreV2() async {
        let hadExistingSpots = await MainActor.run { !self.spots.isEmpty }
        guard moreAvailable else { return }

        await MainActor.run { self.loadState = .loadingMore }

        let location = await currentUserLocation()
        let forceSeenFallback = consecutiveEmptyLoadMore >= 1

        do {
            let rows = try await FeedAPI.fetchHomeFeed(
                limit: pageSize,
                viewerLatitude: location?.coordinate.latitude,
                viewerLongitude: location?.coordinate.longitude,
                forceSeenFallback: forceSeenFallback
            )

            let hydrated = await hydrateRows(rows)
            let existingIds = await MainActor.run { Set(self.spots.compactMap { $0.id }) }
            let newRows = hydrated.filter { spot in
                guard let id = spot.id else { return true }
                return !existingIds.contains(id)
            }

            if newRows.isEmpty {
                consecutiveEmptyLoadMore += 1
                SpotLogger.log(FeedSupabaseLogs.loadMoreNoNewRows, details: [
                    "consecutiveEmpty": consecutiveEmptyLoadMore,
                    "forceSeenFallback": forceSeenFallback
                ])
                await MainActor.run {
                    self.loadState = .loaded
                    if self.consecutiveEmptyLoadMore >= 2 {
                        self.moreAvailable = false
                    }
                }
                return
            }

            consecutiveEmptyLoadMore = 0
            await MainActor.run {
                self.spots.append(contentsOf: newRows)
                self.loadState = .loaded
                self.moreAvailable = true
            }

            SpotLogger.log(FeedRepositoryLogs.loadMore, details: [
                "rows": rows.count,
                "appended": newRows.count
            ])
        } catch is CancellationError {
            SpotLogger.log(FeedRepositoryLogs.loadMoreFailed, details: ["error": "cancelled"])
        } catch {
            SpotLogger.log(FeedRepositoryLogs.loadMoreFailed, details: [
                "error": error.localizedDescription,
                "preserveOldContent": hadExistingSpots
            ])
            await MainActor.run {
                self.loadState = .loaded
                if !hadExistingSpots {
                    self.loadState = .error(message: error.localizedDescription)
                }
            }
        }
    }

    /// Hydrates `HomeFeedRow`s into `Spot`s. With
    /// `FeedFlags.hydrateOnlyPrimaryFeedImage` (default true), only the primary
    /// image URL is signed; full image arrays are loaded lazily on detail.
    private func hydrateRows(_ rows: [HomeFeedRow]) async -> [Spot] {
        guard !rows.isEmpty else { return [] }
        let base: [Spot]
        if FeedFlags.hydrateOnlyPrimaryFeedImage {
            let urlMap = await FeedAPI.resolvePrimaryImageURLs(for: rows)
            base = rows.map { row in
                row.toSpot(primaryURL: urlMap[row.spotId])
            }
        } else {
            var hydrated: [Spot] = []
            hydrated.reserveCapacity(rows.count)
            for row in rows {
                let url = await FeedAPI.resolvePrimaryImageURL(
                    storagePath: row.primaryStoragePath,
                    publicUrl: row.primaryPublicUrl,
                    storageBucket: row.primaryStorageBucket
                )
                hydrated.append(row.toSpot(primaryURL: url))
            }
            base = hydrated
        }
        do {
            return try await SpotSupabaseRepository.enrichSpotsForCardPresentation(base)
        } catch {
            SpotLogger.log(FeedRepositoryLogs.feedEnrichFailed, details: ["error": error.localizedDescription])
            return base
        }
    }

    /// `LocationManager` is main-actor bound because `CLLocationManager` must be
    /// created on a run-loop thread; the feed loads off the main actor, so hop.
    private func currentUserLocation() async -> CLLocation? {
        await MainActor.run { LocationManager.shared.userLocation }
    }

    /// Snapshot for diversity tuning; failures are non-fatal (treated as unknown / low-signal-safe).
    private static func loadOptionalFeedProfileSnapshot() async -> FeedProfileRow? {
        try? await FeedAPI.getMyFeedProfile()
    }
}
