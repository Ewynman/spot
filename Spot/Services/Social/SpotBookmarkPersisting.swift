//
//  SpotBookmarkPersisting.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

protocol SpotBookmarkPersisting: Sendable {
    func upsertBookmark(userId: UUID, spotId: UUID) async throws
    func removeSavedSpot(spotId: UUID) async throws
}
