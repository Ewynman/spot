//
//  MapStyle.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Density mode

/// Selects how spot markers are rendered as a function of zoom.
///
/// - `individualPins`: tight neighborhood zoom — render each pin.
/// - `individualPinsWithSoftOverlap`: city zoom — render individuals, but
///   overlap-resolve identical-coordinate buckets via radial offsets.
/// - `softClusters`: very wide zoom — collapse overflow into soft cluster
///   markers (stacked mini-pins, no large numeric bubbles, no heat maps).
enum MapDensityMode: String, Equatable, Sendable {
    case individualPins
    case individualPinsWithSoftOverlap
    case softClusters
}

extension MapDensityMode {
    /// Returns the density mode appropriate for `region`. Thresholds come
    /// from `Constants.MapDesign` so they can be tuned without code changes
    /// in this file. `region` is treated as the larger of the lat/lon
    /// deltas to avoid a thin viewport flipping into the wrong bucket.
    static func mode(for region: MKCoordinateRegion) -> MapDensityMode {
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        if span <= Constants.MapDesign.localSpan {
            return .individualPins
        } else if span <= Constants.MapDesign.citySpan {
            return .individualPinsWithSoftOverlap
        } else {
            return .softClusters
        }
    }
}

// MARK: - Spot marker visual state

/// Visual state for a `SpotAnnotationView`. The view itself is dumb and
/// just renders whatever state the diffing pass assigns it. This keeps the
/// state-machine in one place and makes it testable without UIKit.
enum SpotMarkerVisualState: Equatable, Sendable {
    case `default`
    case filterMatch
    case filterNonMatch
    case selected
    case pressed
}

/// User type for the user-location avatar marker. Drives ring color in the
/// branded user marker (green for regular, gold for Pro). Does *not* drive
/// the spot pin appearance — those are always green.
enum SpotMapUserKind: String, Equatable, Sendable {
    case regular
    case pro
}

// MARK: - Filter dimensions

/// Pro-only filter dimensions exposed in v1. Client-side filters narrow
/// which pins are drawn on top of the viewport-driven Supabase RPC
/// results — the RPC contract itself is unchanged.
enum SpotMapFilter: String, CaseIterable, Identifiable, Equatable, Sendable {
    case vibe
    case saved
    case liked
    case following

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vibe: return "Vibes"
        case .saved: return "Saved"
        case .liked: return "Liked"
        case .following: return "Following"
        }
    }

    /// SF Symbol used in the floating filter pill.
    var systemImage: String {
        switch self {
        case .vibe: return "tag"
        case .saved: return "bookmark"
        case .liked: return "heart"
        case .following: return "person.2"
        }
    }
}

/// User-facing filter state. Empty = no filter applied. When non-empty,
/// only matching pins are rendered on the map (non-matches are removed).
struct SpotMapFilterState: Equatable, Sendable {
    var dimensions: Set<SpotMapFilter> = []
    /// Vibe tags selected when `.vibe` is in `dimensions`.
    var vibeTags: Set<String> = []

    var isActive: Bool {
        !dimensions.isEmpty
    }

    static let empty = SpotMapFilterState()
}

// MARK: - Marker style resolution

/// Resolves the visual state of a single spot relative to the active filter
/// + selection. Pure function so it can be unit-tested per row.
struct SpotMarkerStyleResolver {

    /// Returns the visual state for `spot` given the current selection,
    /// filter, and the current user's saved/liked/follow lists.
    ///
    /// When a filter is active, `SharedSpotMap` only renders spots that
    /// already match the filter, so every visible pin is a match — there
    /// is no `.filterNonMatch` path on the discovery map anymore.
    static func state(
        for spot: Spot,
        selectedSpotId: String?,
        filter: SpotMapFilterState,
        savedSpotIds: Set<String>,
        likedSpotIds: Set<String>,
        followedUserIds: Set<String>
    ) -> SpotMarkerVisualState {
        if let id = spot.id, id == selectedSpotId {
            return .selected
        }
        guard filter.isActive else { return .default }
        return .filterMatch
    }

    /// Returns true iff `spot` matches every active filter dimension.
    /// A filter is treated as AND across dimensions and OR within
    /// dimensions (e.g., any selected vibe matches).
    static func matches(
        _ spot: Spot,
        filter: SpotMapFilterState,
        savedSpotIds: Set<String>,
        likedSpotIds: Set<String>,
        followedUserIds: Set<String>
    ) -> Bool {
        guard filter.isActive else { return true }
        for dim in filter.dimensions {
            switch dim {
            case .vibe:
                guard let v = spot.vibeTag, !filter.vibeTags.isEmpty,
                      filter.vibeTags.contains(v) else { return false }
            case .saved:
                guard let id = spot.id, savedSpotIds.contains(id) else { return false }
            case .liked:
                guard let id = spot.id, likedSpotIds.contains(id) else { return false }
            case .following:
                guard let uid = spot.userId, followedUserIds.contains(uid) else { return false }
            }
        }
        return true
    }
}

// MARK: - Map camera (pure helpers)

/// Pure helpers for intent-based camera regions so `MapView` and tests
/// share one definition of “neighborhood” zoom.
enum MapCameraRegion {

    /// Region centered on `center` with roughly `radiusMeters` extent.
    /// Uses `MKCoordinateRegion` meters API so span scales with latitude.
    static func neighborhood(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )
    }
}

// MARK: - Filtered spot list (discovery)

/// Spots actually drawn on the map when Pro filters are active.
/// Non-matching rows are omitted entirely (no dimmed pins).
enum SpotMapDisplayFilter {
    static func spotsToDisplay(
        _ spots: [Spot],
        filter: SpotMapFilterState,
        savedSpotIds: Set<String>,
        likedSpotIds: Set<String>,
        followedUserIds: Set<String>
    ) -> [Spot] {
        guard filter.isActive else { return spots }
        return spots.filter {
            SpotMarkerStyleResolver.matches(
                $0,
                filter: filter,
                savedSpotIds: savedSpotIds,
                likedSpotIds: likedSpotIds,
                followedUserIds: followedUserIds
            )
        }
    }
}

// MARK: - Filter gating

/// Whether the filter pill row should be visible to the current viewer.
/// Eddie's call: hidden entirely for non-Pro users. The filter pill uses
/// this directly so non-Pro never sees the entry point.
struct MapFilterGate {
    /// Returns true iff filter UI should be exposed to the viewer.
    static func isAvailable(isPro: Bool) -> Bool { isPro }
}

// MARK: - Animation delay

/// Stable, deterministic per-pin entry delay so re-renders don't chaotically
/// re-animate already-visible pins. The delay is derived from the spot id
/// (or, when missing, from the coordinate hash) and capped to
/// `Constants.MapDesign.pinStaggerCap` so the whole batch finishes within a
/// quarter second.
enum MapAnimationDelay {

    /// Compute the entry delay (in seconds) for a single pin. Pure
    /// function — same input always yields the same delay, regardless of
    /// view churn.
    static func delay(forSpotId id: String?, fallback coord: CLLocationCoordinate2D) -> Double {
        let key: UInt64
        if let id, !id.isEmpty {
            key = stableHash(id)
        } else {
            key = stableHash("\(coord.latitude),\(coord.longitude)")
        }
        let step = Constants.MapDesign.pinStaggerStep
        let cap = Constants.MapDesign.pinStaggerCap
        // Map hash to [0, cap] in 16-step buckets so adjacent hashes don't
        // produce identical delays.
        let buckets = max(1, Int(cap / step))
        let bucket = Int(key % UInt64(buckets))
        return min(Double(bucket) * step, cap)
    }

    /// FNV-1a 64-bit. Stable across launches, unlike Swift's `Hasher`,
    /// which uses per-process randomization.
    private static func stableHash(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

// MARK: - Panel height clamp

/// Computes a safe map preview panel height. The panel:
///
///  * has a minimum of `panelMinHeight` so the spot card header is never cut,
///  * never exceeds `panelMaxScreenFraction * available height` so it cannot
///    push controls off-screen on small devices,
///  * always sits above the bottom safe-area inset (home indicator).
///
/// Returned tuple: `(height, wasClamped)`. The boolean lets callers emit a
/// `MapViewLogs.panelHeightClamped` log when their requested height was
/// reduced — useful for QA on the IMG_9741 overflow scenario.
struct MapPanelHeight {

    static func clamp(
        requested: CGFloat,
        availableHeight: CGFloat,
        bottomSafeArea: CGFloat
    ) -> (height: CGFloat, wasClamped: Bool) {
        let usable = max(0, availableHeight - bottomSafeArea)
        let upper = max(Constants.MapDesign.panelMinHeight,
                        usable * Constants.MapDesign.panelMaxScreenFraction)
        let lower = min(Constants.MapDesign.panelMinHeight, upper)
        let raw = max(lower, min(upper, requested))
        let clamped = raw < requested
        return (raw, clamped)
    }
}
