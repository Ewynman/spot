import Foundation

/// How vibe tags are shown on a Spot card.
enum VibeDisplayMode: String, Codable, Equatable, Sendable {
    case rotating
    case photoSynced = "photo_synced"

    init(rawValueOrDefault raw: String?) {
        guard let raw, let mode = VibeDisplayMode(rawValue: raw) else {
            self = .rotating
            return
        }
        self = mode
    }
}

/// Pure helpers for Match Vibes to Photos (composer + edit).
enum VibePhotoMappingPolicy {
    static let unequalCountsMessage =
        "Vibes will rotate because each photo no longer has its own Vibe."

    static func isEligible(photoCount: Int, vibeCount: Int, isPro: Bool) -> Bool {
        guard isPro else { return false }
        return photoCount >= 2
            && vibeCount >= 2
            && photoCount == vibeCount
            && photoCount <= Constants.PostLimits.maxProPostImages
            && vibeCount <= Constants.PostLimits.maxProPostVibes
    }

    /// Pair vibes to photos by current order (1:1).
    static func initialMappings(photoIds: [UUID], vibes: [String]) -> [UUID: String] {
        guard photoIds.count == vibes.count else { return [:] }
        var out: [UUID: String] = [:]
        out.reserveCapacity(photoIds.count)
        for (id, vibe) in zip(photoIds, vibes) {
            out[id] = vibe
        }
        return out
    }

    /// Assign `newVibe` to `photoId`, swapping with whichever photo currently holds it.
    static func swapMapping(
        mappings: [UUID: String],
        photoId: UUID,
        newVibe: String
    ) -> [UUID: String] {
        guard let current = mappings[photoId], current != newVibe else { return mappings }
        var next = mappings
        if let otherPhoto = next.first(where: { $0.value == newVibe })?.key {
            next[otherPhoto] = current
        }
        next[photoId] = newVibe
        return next
    }

    /// Ordered vibe labels for publish/edit RPC (parallel to photo order).
    static func orderedVibes(photoIds: [UUID], mappings: [UUID: String]) -> [String]? {
        var labels: [String] = []
        labels.reserveCapacity(photoIds.count)
        for id in photoIds {
            guard let vibe = mappings[id] else { return nil }
            labels.append(vibe)
        }
        return labels
    }

    /// Drop mappings for removed photos/vibes; return whether sync remains valid.
    static func reconcile(
        photoIds: [UUID],
        vibes: [String],
        mappings: [UUID: String],
        matchEnabled: Bool,
        isPro: Bool
    ) -> (matchEnabled: Bool, mappings: [UUID: String], didInvalidate: Bool) {
        let vibeSet = Set(vibes)
        var cleaned = mappings.filter { photoIds.contains($0.key) && vibeSet.contains($0.value) }

        guard matchEnabled else {
            return (false, cleaned, false)
        }

        let eligible = isEligible(photoCount: photoIds.count, vibeCount: vibes.count, isPro: isPro)
        if !eligible {
            return (false, [:], true)
        }

        // Ensure every photo has a mapping; fill gaps from unused vibes in order.
        let used = Set(cleaned.values)
        var unused = vibes.filter { !used.contains($0) }
        for id in photoIds where cleaned[id] == nil {
            if let next = unused.first {
                cleaned[id] = next
                unused.removeFirst()
            }
        }

        if cleaned.count != photoIds.count
            || Set(cleaned.values).count != vibes.count {
            return (false, [:], true)
        }
        return (true, cleaned, false)
    }

    /// Card label for PHOTO_SYNCED given a committed carousel index.
    static func syncedLabel(
        photoSyncedVibeLabels: [String]?,
        index: Int,
        fallback: [String]
    ) -> String? {
        if let labels = photoSyncedVibeLabels, labels.indices.contains(index) {
            return labels[index]
        }
        if fallback.indices.contains(index) {
            return fallback[index]
        }
        return fallback.first
    }
}
