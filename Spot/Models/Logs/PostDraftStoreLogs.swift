//
//  PostDraftStoreLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum PostDraftStoreLogs: SpotLog {
    case draftsDirectoryCreateFailed
    case draftIndexDecodeFailed
    case draftIndexEncodeFailed
    case draftImageWriteFailed
    case draftWriteFailed
    case draftReadFailed
    case draftDecodeFailed
    case draftImageReadFailed
    case draftDeleted

    var tag: String { "PostDraftStore" }

    var level: LogLevel {
        switch self {
        case .draftDeleted:
            return .info
        case .draftsDirectoryCreateFailed,
                .draftIndexDecodeFailed,
                .draftIndexEncodeFailed,
                .draftImageWriteFailed,
                .draftWriteFailed,
                .draftReadFailed,
                .draftDecodeFailed,
                .draftImageReadFailed:
            return .error
        }
    }

    var message: String {
        switch self {
        case .draftsDirectoryCreateFailed:
            return "Failed to create drafts directory"
        case .draftIndexDecodeFailed:
            return "Failed to decode draft index"
        case .draftIndexEncodeFailed:
            return "Failed to encode or persist draft index"
        case .draftImageWriteFailed:
            return "Failed to persist draft image"
        case .draftWriteFailed:
            return "Failed to persist draft payload"
        case .draftReadFailed:
            return "Failed to read draft payload"
        case .draftDecodeFailed:
            return "Failed to decode draft payload"
        case .draftImageReadFailed:
            return "Failed to read draft image from disk"
        case .draftDeleted:
            return "Draft deleted"
        }
    }
}
