//
//  UserSpotServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum UserSpotServiceLogs: SpotLog {
    case noUserIdAvailable
    case fetchingLikedSpots
    case foundLikedSpotIds
    case noLikedSpotsFound
    case fetchSpotFailed

    case followAttempt
    case followSucceeded
    case followFailed
    case followDuplicateIgnored
    case unfollowAttempt
    case unfollowSucceeded
    case unfollowFailed

    var tag: String { "UserSpotService" }
    var level: LogLevel {
        switch self {
        case .noUserIdAvailable: return .error
        case .fetchingLikedSpots: return .info
        case .foundLikedSpotIds: return .info
        case .noLikedSpotsFound: return .info
        case .fetchSpotFailed: return .error
        case .followAttempt, .unfollowAttempt: return .info
        case .followSucceeded, .unfollowSucceeded: return .info
        case .followFailed, .unfollowFailed: return .error
        case .followDuplicateIgnored: return .info
        }
    }
    var message: String {
        switch self {
        case .noUserIdAvailable: return "No user ID available"
        case .fetchingLikedSpots: return "Fetching liked spots for user"
        case .foundLikedSpotIds: return "Found liked spot IDs"
        case .noLikedSpotsFound: return "No liked spots found"
        case .fetchSpotFailed: return "Failed to fetch spot"
        case .followAttempt: return "Follow attempt"
        case .followSucceeded: return "Follow succeeded"
        case .followFailed: return "Follow failed"
        case .followDuplicateIgnored: return "Follow insert skipped (already following)"
        case .unfollowAttempt: return "Unfollow attempt"
        case .unfollowSucceeded: return "Unfollow succeeded"
        case .unfollowFailed: return "Unfollow failed"
        }
    }
}
