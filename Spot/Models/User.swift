//
//  User.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

struct User: Identifiable, Codable {
    var id: String?
    var username: String
    var profileImageURL: String?
    var isPrivate: Bool
    var isCurrentUser: Bool
    var vibeStats: [String: Int]?
    var createdAt: Date?
    var blockedUsers: [String]?
    var customVibeTags: [String]?

    // Preview data
    static let previewUser = User(
        id: "preview123",
        username: "Eddie Wynman",
        profileImageURL: nil,
        isPrivate: false,
        isCurrentUser: true,
        vibeStats: [
            "Chill Spot": 5,
            "Hidden Gem": 3,
            "Photo Op": 2
        ],
        createdAt: Date(),
        blockedUsers: [],
        customVibeTags: ["Fishing", "Golden Hour"]
    )
}
