//
//  SpotMapFilterStateTransitions.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Pure filter-state transitions for map filter pills / vibe sheet.
extension SpotMapFilterState {
    /// Toggles a dimension. Clearing `.vibe` also clears vibe tags.
    /// - Returns: whether the vibe picker should open (dimension newly enabled).
    mutating func toggling(_ dimension: SpotMapFilter) -> Bool {
        if dimensions.contains(dimension) {
            dimensions.remove(dimension)
            if dimension == .vibe {
                vibeTags.removeAll()
            }
            return false
        } else {
            dimensions.insert(dimension)
            return dimension == .vibe
        }
    }

    mutating func togglingVibeTag(_ tag: String) {
        if vibeTags.contains(tag) {
            vibeTags.remove(tag)
        } else {
            vibeTags.insert(tag)
            dimensions.insert(.vibe)
        }
    }
}
