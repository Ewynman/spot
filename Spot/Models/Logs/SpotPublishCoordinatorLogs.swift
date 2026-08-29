//
//  SpotPublishCoordinatorLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotPublishCoordinatorLogs: SpotLog {
    case imageDecodeFailed
    case spotUploadFailed
    case spotUploadTimedOut
    case spotPublished

    var tag: String { "SpotPublishCoordinator" }

    var level: LogLevel {
        switch self {
        case .imageDecodeFailed, .spotUploadFailed, .spotUploadTimedOut:
            return .error
        case .spotPublished:
            return .info
        }
    }

    var message: String {
        switch self {
        case .imageDecodeFailed:
            return "Publish pipeline: could not decode JPEG drafts to images"
        case .spotUploadFailed:
            return "Publish pipeline: spot publish failed"
        case .spotUploadTimedOut:
            return "Publish pipeline: spot publish timed out"
        case .spotPublished:
            return "Publish pipeline: spot published to Supabase"
        }
    }
}
