//
//  MapMarkerFeatureFlags.swift
//  Spot
//
//  Runtime toggles for the map marker subsystem. Flags here are static
//  Swift vars so QA can flip them in DEBUG builds without a codegen step,
//  and unit tests can mutate them via `withValue(_:body:)` to lock in the
//  legacy behavior while exercising the new photo pin path.
//
//  Only additive gates belong here; anything with a data-plane impact
//  should live behind a remote flag instead.
//

import Foundation

enum MapMarkerFeatureFlags {

    /// Master switch for the Concept 3 photo-preview pin rollout.
    ///
    /// * `true` (default) — spots with a signed primary image render as a
    ///   circular photo preview inside a pin silhouette. Spots without an
    ///   image fall back to the legacy teardrop.
    /// * `false` — every spot renders the legacy teardrop pin.
    ///
    /// The flag is intentionally in-process only; it does not persist
    /// across launches. Use it to A/B locally or from tests.
    static var photoPinMarkersEnabled: Bool = true

    /// Test / QA helper: temporarily override the flag inside `body`,
    /// restoring the prior value even if `body` throws.
    @discardableResult
    static func withPhotoPinMarkers<T>(_ enabled: Bool, body: () throws -> T) rethrows -> T {
        let previous = photoPinMarkersEnabled
        photoPinMarkersEnabled = enabled
        defer { photoPinMarkersEnabled = previous }
        return try body()
    }
}
