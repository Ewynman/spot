//
//  Spot+Extensions.swift
//  Spot
//
//  Created by Edward Wynman on 1/12/26.
//

import Foundation

extension Spot {
    /// Safe ID that returns the spot's ID or "nil" if the ID is nil
    var safeId: String {
        return id ?? "nil"
    }

    /// Fields that can change after a feed refresh while `id` stays the same (likes, media, saves).
    /// Used so `SpotCard` can sync `@State currentSpot` from the parent `spot` when SwiftUI reuses the row.
    var feedRowSyncToken: String {
        "\(safeId)|\(imageURL ?? "")|\(username ?? "")|\(userProfileImageURL ?? "")|\(likes ?? -1)|\(isLiked ?? false)|\(isSaved ?? false)|\(mediaCount ?? -1)"
    }
}

struct SpotAuthorDisplay: Equatable {
    let username: String
    let profileImageURL: String?

    static func resolve(
        spotUsername: String?,
        spotProfileImageURL: String?,
        isCurrentUser: Bool,
        currentUsername: String?,
        currentProfileImageURL: String?
    ) -> SpotAuthorDisplay {
        let spotName = spotUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentName = currentUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = nonempty(spotName)
            ?? (isCurrentUser ? nonempty(currentName) : nil)
            ?? "User"
        let profileImageURL = nonempty(spotProfileImageURL)
            ?? (isCurrentUser ? nonempty(currentProfileImageURL) : nil)
        return SpotAuthorDisplay(username: username, profileImageURL: profileImageURL)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}