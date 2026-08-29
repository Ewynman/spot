//
//  SpotListDeduper.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Session-local spot list dedupe used by likes/bookmarks view models.
enum SpotListDeduper {
    static func accepting(_ spots: [Spot], into knownIds: inout Set<String>) -> [Spot] {
        spots.filter { spot in
            guard let spotId = spot.id else { return false }
            let isNew = !knownIds.contains(spotId)
            if isNew {
                knownIds.insert(spotId)
            }
            return isNew
        }
    }
}
