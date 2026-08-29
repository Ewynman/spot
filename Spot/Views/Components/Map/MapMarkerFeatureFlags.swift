//
//  MapMarkerFeatureFlags.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
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
