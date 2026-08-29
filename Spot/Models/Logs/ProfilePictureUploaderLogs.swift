//
//  ProfilePictureUploaderLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum ProfilePictureUploaderLogs: SpotLog {
    case compressionFailed
    case uploadingToPath
    case uploadFailed
    case gettingDownloadUrl
    case downloadUrlFailed
    case uploadSucceededButUrlNil
    case uploadedSuccessfully

    var tag: String { "ProfilePictureUploader" }
    var level: LogLevel {
        switch self {
        case .compressionFailed: return .error
        case .uploadingToPath: return .debug
        case .uploadFailed: return .error
        case .gettingDownloadUrl: return .debug
        case .downloadUrlFailed: return .error
        case .uploadSucceededButUrlNil: return .error
        case .uploadedSuccessfully: return .info
        }
    }
    var message: String {
        switch self {
        case .compressionFailed: return "Failed to compress profile picture to JPEG"
        case .uploadingToPath: return "Uploading profile picture to path"
        case .uploadFailed: return "Failed to upload profile picture"
        case .gettingDownloadUrl: return "Profile picture uploaded, getting download URL"
        case .downloadUrlFailed: return "Failed to get profile picture download URL"
        case .uploadSucceededButUrlNil: return "Profile picture upload succeeded but URL is nil"
        case .uploadedSuccessfully: return "Profile picture uploaded successfully"
        }
    }
}
