//
//  SpotVibeSyncHydration.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Pure helpers for photo-synced vibe hydration (unit-tested; used by repository mappers).
enum SpotVibeSyncHydration {
    struct ImageVibeRow: Equatable, Sendable {
        let spotId: UUID
        let sortIndex: Int
        let vibeTagId: UUID?
    }

    struct ModeRow: Equatable, Sendable {
        let id: UUID
        let vibeDisplayMode: String?
    }

    /// Ordered vibe labels per spot from `spot_images.vibe_tag_id` rows.
    static func photoSyncedLabelsBySpotId(
        rows: [ImageVibeRow],
        namesByVibeId: [UUID: String]
    ) -> [UUID: [String]] {
        guard !rows.isEmpty else { return [:] }
        var bySpot: [UUID: [String]] = [:]
        let grouped = Dictionary(grouping: rows, by: \.spotId)
        for (sid, imageRows) in grouped {
            let sorted = imageRows.sorted { $0.sortIndex < $1.sortIndex }
            let names = sorted.compactMap { row -> String? in
                guard let vibeId = row.vibeTagId else { return nil }
                return namesByVibeId[vibeId]
            }
            if !names.isEmpty { bySpot[sid] = names }
        }
        return bySpot
    }

    static func displayModesBySpotId(rows: [ModeRow]) -> [UUID: VibeDisplayMode] {
        var out: [UUID: VibeDisplayMode] = [:]
        for row in rows {
            out[row.id] = VibeDisplayMode(rawValueOrDefault: row.vibeDisplayMode)
        }
        return out
    }

    static func displayModes(
        spotIds: [UUID],
        loadRows: ([UUID]) async throws -> [ModeRow]
    ) async throws -> [UUID: VibeDisplayMode] {
        guard !spotIds.isEmpty else { return [:] }
        let rows = try await loadRows(spotIds)
        return displayModesBySpotId(rows: rows)
    }

    /// When mode is photo-synced, ordered junction labels are the photo mapping.
    static func photoSyncedLabels(
        mode: VibeDisplayMode,
        junctionLabels: [String]?,
        explicitSynced: [String]? = nil
    ) -> [String]? {
        if let explicitSynced, !explicitSynced.isEmpty {
            return explicitSynced
        }
        guard mode == .photoSynced else { return nil }
        guard let junctionLabels, !junctionLabels.isEmpty else { return nil }
        return junctionLabels
    }

    /// Merge vibe labels / display mode / photo-synced labels / author Pro onto card Spots.
    static func applyCardEnrichment(
        spots: [Spot],
        labelsBySpotId: [UUID: [String]],
        modeBySpotId: [UUID: VibeDisplayMode],
        syncedLabelsBySpotId: [UUID: [String]] = [:],
        authorProByUserId: [String: Bool]
    ) -> [Spot] {
        spots.map { spot in
            var updated = spot
            if let sid = spot.id, let uuid = UUID(uuidString: sid) {
                if let labs = labelsBySpotId[uuid], !labs.isEmpty {
                    updated.vibeTags = labs
                    updated.vibeTag = labs.first
                }
                let mode = modeBySpotId[uuid] ?? .rotating
                updated.vibeDisplayMode = mode
                updated.photoSyncedVibeLabels = photoSyncedLabels(
                    mode: mode,
                    junctionLabels: labelsBySpotId[uuid] ?? updated.displayVibeTags,
                    explicitSynced: syncedLabelsBySpotId[uuid]
                )
            }
            if let uid = spot.userId {
                updated.authorIsPro = authorProByUserId[uid]
            }
            return updated
        }
    }

    /// Attach vibe-sync fields after constructing a base Spot from a DB row.
    static func attaching(
        to spot: Spot,
        vibeDisplayModeRaw: String?,
        junctionLabels: [String]? = nil,
        photoSyncedLabels explicitSynced: [String]? = nil
    ) -> Spot {
        var updated = spot
        let mode = VibeDisplayMode(rawValueOrDefault: vibeDisplayModeRaw)
        updated.vibeDisplayMode = mode
        updated.photoSyncedVibeLabels = photoSyncedLabels(
            mode: mode,
            junctionLabels: junctionLabels ?? spot.displayVibeTags,
            explicitSynced: explicitSynced
        )
        return updated
    }

    /// RPC string for `p_vibe_display_mode`.
    static func publishDisplayModeParam(_ mode: VibeDisplayMode) -> String {
        mode.rawValue
    }

    /// Async card enrichment orchestration (injectable fetchers for unit tests).
    static func enrichSpotsForCardPresentation(
        _ spots: [Spot],
        fetchLabels: ([UUID]) async throws -> [UUID: [String]],
        fetchModes: ([UUID]) async throws -> [UUID: VibeDisplayMode],
        fetchPro: ([UUID]) async throws -> [String: Bool]
    ) async throws -> [Spot] {
        let spotUUIDs = spots.compactMap { $0.id }.compactMap(UUID.init)
        guard !spotUUIDs.isEmpty else { return spots }

        let userUUIDs = Array(Set(spots.compactMap { $0.userId }.compactMap(UUID.init)))
        async let labelTask = fetchLabels(spotUUIDs)
        async let modeTask = fetchModes(spotUUIDs)
        async let proTask = fetchPro(userUUIDs)
        let (labelMap, modeMap, proMap) = try await (labelTask, modeTask, proTask)

        return applyCardEnrichment(
            spots: spots,
            labelsBySpotId: labelMap,
            modeBySpotId: modeMap,
            authorProByUserId: proMap
        )
    }
}

extension Spot {
    /// Attaches vibe display mode + photo-synced labels derived from junction order.
    func withVibeSync(modeRaw: String?, junctionLabels: [String]) -> Spot {
        SpotVibeSyncHydration.attaching(
            to: self,
            vibeDisplayModeRaw: modeRaw,
            junctionLabels: junctionLabels
        )
    }
}

extension SpotVibeSyncHydration {
    /// Applies vibe-sync fields using already-loaded spot rows + junction labels.
    static func applyingRowModes(
        spots: [Spot],
        modeBySpotId: [UUID: String?],
        labelsBySpotId: [UUID: [String]]
    ) -> [Spot] {
        spots.map { spot in
            guard let sid = spot.id, let uuid = UUID(uuidString: sid) else { return spot }
            return spot.withVibeSync(
                modeRaw: modeBySpotId[uuid] ?? nil,
                junctionLabels: labelsBySpotId[uuid] ?? spot.displayVibeTags
            )
        }
    }
}
