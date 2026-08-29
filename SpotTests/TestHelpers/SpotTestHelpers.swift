//
//  SpotTestHelpers.swift
//  SpotTests
//
//  Created by Edward Wynman on 4/27/26.
//

import Foundation
@testable import Spot

enum SpotTestHelpers {

    /// Returns a `UserDefaults` instance backed by an ephemeral suite, so each
    /// test can mutate keys (onboarding completion, last step, etc.) without
    /// leaking into `UserDefaults.standard` or sibling tests.
    ///
    /// Tests should call `removePersistentDomain(forName:)` before passing the
    /// store into a manager so suite reuse never leaks state across runs of
    /// the same test executable.
    static func makeIsolatedDefaults(
        suiteName: String = "spot.tests.\(UUID().uuidString)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)
            ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Builds a minimal `Spot` fixture suitable for repository, ranking, and
    /// view-model tests. All optional fields default to `nil` so individual
    /// callers can override exactly what they care about.
    static func makeSpot(
        id: String? = "spot-1",
        userId: String? = "user-1",
        username: String? = nil,
        vibeTag: String? = "Chill",
        vibeTags: [String]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        likes: Int? = nil,
        createdAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
        authorIsPrivate: Bool? = nil,
        imageURLs: [String]? = nil
    ) -> Spot {
        Spot(
            id: id,
            userId: userId,
            username: username,
            userProfileImageURL: nil,
            imageURL: nil,
            thumbnailURL: nil,
            vibeTag: vibeTag,
            vibeTags: vibeTags,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            likes: likes,
            isLiked: nil,
            isSaved: nil,
            createdAt: createdAt,
            authorIsPrivate: authorIsPrivate,
            imageURLs: imageURLs
        )
    }

    /// Builds a sequence of spots, mostly for ranking / dedupe / merge tests
    /// where ID matters but the rest is filler.
    static func makeSpots(ids: [String], userId: String = "user-1") -> [Spot] {
        ids.map { makeSpot(id: $0, userId: userId) }
    }
}
