//
//  FeedProfileContentPolicy.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Whether a feed profile snapshot has anything meaningful to show.
enum FeedProfileContentPolicy {
    static func hasContent(topVibes: Int, topCreators: Int, events30d: Int) -> Bool {
        topVibes > 0 || topCreators > 0 || events30d > 0
    }

    static func hasContent(_ profile: FeedProfile?) -> Bool {
        guard let profile else { return false }
        return hasContent(
            topVibes: profile.topVibes.count,
            topCreators: profile.topCreators.count,
            events30d: profile.eventSummary30d.total
        )
    }
}
