//
//  AuthorPrivacyCacheLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum AuthorPrivacyCacheLogs: SpotLog {
    case cacheWarm
    case cacheWarmFailed
    case cacheMiss
    case privacyDropBlockedUser
    case privacyDropPrivateNotFollowed
    case privacyDropUnknownAuthor
    case refreshFollowingFailed
    case refreshBlockedUsersFailed

    var tag: String { "AuthorPrivacyCache" }
    var level: LogLevel {
        switch self {
        case .cacheWarm: return .info
        case .cacheWarmFailed: return .error
        case .cacheMiss: return .debug
        case .privacyDropBlockedUser: return .debug
        case .privacyDropPrivateNotFollowed: return .debug
        case .privacyDropUnknownAuthor: return .debug
        case .refreshFollowingFailed: return .error
        case .refreshBlockedUsersFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .cacheWarm: return "Privacy cache warming"
        case .cacheWarmFailed: return "Privacy cache warm failed for chunk"
        case .cacheMiss: return "Privacy cache miss"
        case .privacyDropBlockedUser: return "Privacy drop: blocked user"
        case .privacyDropPrivateNotFollowed: return "Privacy drop: private user not followed"
        case .privacyDropUnknownAuthor: return "Privacy drop: unknown author"
        case .refreshFollowingFailed: return "Failed to refresh following list"
        case .refreshBlockedUsersFailed: return "Failed to refresh blocked users"
        }
    }
}
