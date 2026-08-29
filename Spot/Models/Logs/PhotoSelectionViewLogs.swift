//
//  PhotoSelectionViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum PhotoSelectionViewLogs: SpotLog {
    case photosSelectedFromGallery
    case loadPhotosFailed
    case photoCapturedWithCamera
    case capturePhotoFailed
    case cameraCancelled

    var tag: String { "PhotoSelectionView" }
    var level: LogLevel {
        switch self {
        case .photosSelectedFromGallery: return .info
        case .loadPhotosFailed: return .error
        case .photoCapturedWithCamera: return .info
        case .capturePhotoFailed: return .error
        case .cameraCancelled: return .debug
        }
    }
    var message: String {
        switch self {
        case .photosSelectedFromGallery: return "User selected photos from gallery"
        case .loadPhotosFailed: return "Failed to load selected photos from gallery"
        case .photoCapturedWithCamera: return "User captured photo with camera"
        case .capturePhotoFailed: return "Failed to capture photo with camera"
        case .cameraCancelled: return "User cancelled camera capture"
        }
    }
}
