//
//  PostComposerPhoto.swift
//  Spot
//
//  Stable identity for composer photos so SwiftUI lists / TabView pages don’t
//  reuse the wrong view when reordering or replacing images.
//

import Foundation
import UIKit

enum PostComposerPhotoSource: String, Codable, Sendable {
    case gallery
    case camera
    case legacyDraft
}

enum PostComposerPhotoProcessingState: String, Codable, Sendable {
    case idle
    case processing
    case ready
    case failed
    case unavailable
}

struct PostComposerPhotoCrop: Codable, Equatable, Sendable {
    var normalizedX: CGFloat
    var normalizedY: CGFloat
    var normalizedWidth: CGFloat
    var normalizedHeight: CGFloat
    var aspectRatio: String?

    static let fullImage = PostComposerPhotoCrop(
        normalizedX: 0,
        normalizedY: 0,
        normalizedWidth: 1,
        normalizedHeight: 1,
        aspectRatio: nil
    )
}

struct PostComposerPhotoAdjustments: Codable, Equatable, Sendable {
    var brightness: Double
    var contrast: Double
    var saturation: Double
    var warmth: Double

    static let neutral = PostComposerPhotoAdjustments(
        brightness: 0,
        contrast: 0,
        saturation: 0,
        warmth: 0
    )

    var isNeutral: Bool { self == .neutral }
}

struct PostComposerPhotoEdits: Codable, Equatable, Sendable {
    var rotationQuarterTurns: Int
    var straightenDegrees: Double
    var flipHorizontal: Bool
    var flipVertical: Bool
    var crop: PostComposerPhotoCrop
    var adjustments: PostComposerPhotoAdjustments

    static let neutral = PostComposerPhotoEdits(
        rotationQuarterTurns: 0,
        straightenDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        crop: .fullImage,
        adjustments: .neutral
    )

    var isNeutral: Bool { self == .neutral }

    mutating func normalize() {
        rotationQuarterTurns = ((rotationQuarterTurns % 4) + 4) % 4
        straightenDegrees = min(15, max(-15, straightenDegrees))
        crop.normalizedX = min(0.99, max(0, crop.normalizedX))
        crop.normalizedY = min(0.99, max(0, crop.normalizedY))
        crop.normalizedWidth = min(1 - crop.normalizedX, max(0.01, crop.normalizedWidth))
        crop.normalizedHeight = min(1 - crop.normalizedY, max(0.01, crop.normalizedHeight))
        adjustments.brightness = min(1, max(-1, adjustments.brightness))
        adjustments.contrast = min(1, max(-1, adjustments.contrast))
        adjustments.saturation = min(1, max(-1, adjustments.saturation))
        adjustments.warmth = min(1, max(-1, adjustments.warmth))
    }
}

struct PostComposerPhoto: Identifiable {
    let id: UUID
    var originalImage: UIImage
    var image: UIImage
    var source: PostComposerPhotoSource
    var edits: PostComposerPhotoEdits
    var processingState: PostComposerPhotoProcessingState
    var processingError: String?
    var createdAt: Date
    var renderRevision: UUID

    init(
        id: UUID = UUID(),
        image: UIImage,
        originalImage: UIImage? = nil,
        source: PostComposerPhotoSource = .gallery,
        edits: PostComposerPhotoEdits = .neutral,
        processingState: PostComposerPhotoProcessingState = .ready,
        processingError: String? = nil,
        createdAt: Date = Date(),
        renderRevision: UUID = UUID()
    ) {
        self.id = id
        self.originalImage = originalImage ?? image
        self.image = image
        self.source = source
        self.edits = edits
        self.processingState = processingState
        self.processingError = processingError
        self.createdAt = createdAt
        self.renderRevision = renderRevision
    }

    var pixelWidth: Int { Int(originalImage.size.width * originalImage.scale) }
    var pixelHeight: Int { Int(originalImage.size.height * originalImage.scale) }
    var hasBlockingError: Bool { processingState == .failed || processingState == .unavailable }
    var isReadyForUpload: Bool { processingState == .ready || processingState == .idle }
}

extension PostComposerPhoto: Equatable {
    static func == (lhs: PostComposerPhoto, rhs: PostComposerPhoto) -> Bool {
        lhs.id == rhs.id &&
            lhs.image === rhs.image &&
            lhs.edits == rhs.edits &&
            lhs.processingState == rhs.processingState &&
            lhs.processingError == rhs.processingError &&
            lhs.renderRevision == rhs.renderRevision
    }
}

enum PostComposerPhotoOperations {
    static func reordered(_ photos: [PostComposerPhoto], from source: Int, to destination: Int) -> [PostComposerPhoto] {
        guard source != destination,
              photos.indices.contains(source),
              photos.indices.contains(destination) else { return photos }
        var result = photos
        let photo = result.remove(at: source)
        result.insert(photo, at: destination)
        return result
    }

    static func makingCover(_ photos: [PostComposerPhoto], id: UUID) -> [PostComposerPhoto] {
        guard let source = photos.firstIndex(where: { $0.id == id }), source != 0 else { return photos }
        return reordered(photos, from: source, to: 0)
    }
}
