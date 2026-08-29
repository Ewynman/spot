//
//  PostPhotoProcessor.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreImage
import ImageIO
import UniformTypeIdentifiers
import UIKit

enum PostPhotoImportError: LocalizedError, Equatable {
    case unsupportedMedia
    case video
    case unreadable
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .video:
            return "Videos can’t be added to a Spot. Choose a photo instead."
        case .unsupportedMedia:
            return "This file isn’t a supported photo."
        case .unreadable, .decodeFailed:
            return "This photo couldn’t be opened."
        }
    }
}

enum PostPhotoProcessor {
    static let previewMaxPixelSize: CGFloat = 1_600
    static let editorPreviewMaxPixelSize: CGFloat = 900
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func importImage(
        data: Data,
        source: PostComposerPhotoSource
    ) throws -> PostComposerPhoto {
        guard !data.isEmpty else { throw PostPhotoImportError.unreadable }
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(imageSource) > 0 else {
            throw PostPhotoImportError.unsupportedMedia
        }
        guard let type = CGImageSourceGetType(imageSource) as String?,
              UTTypeConformance.conformsToImage(type) else {
            throw PostPhotoImportError.unsupportedMedia
        }

        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: previewMaxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) else {
            throw PostPhotoImportError.decodeFailed
        }
        let normalized = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        return PostComposerPhoto(
            image: normalized,
            originalImage: normalized,
            source: source
        )
    }

    static func importCameraImage(_ image: UIImage) throws -> PostComposerPhoto {
        guard let normalized = normalizeOrientationAndResize(image, maxPixelSize: previewMaxPixelSize) else {
            throw PostPhotoImportError.decodeFailed
        }
        return PostComposerPhoto(
            image: normalized,
            originalImage: normalized,
            source: .camera
        )
    }

    static func render(original: UIImage, edits proposedEdits: PostComposerPhotoEdits) throws -> UIImage {
        try render(
            original: original,
            edits: proposedEdits,
            maxPixelSize: previewMaxPixelSize
        )
    }

    /// Fast, display-only render used while editor controls are moving. The
    /// full 1600px render still runs after the user taps Done.
    static func renderEditorPreview(
        original: UIImage,
        edits proposedEdits: PostComposerPhotoEdits
    ) throws -> UIImage {
        try render(
            original: original,
            edits: proposedEdits,
            maxPixelSize: editorPreviewMaxPixelSize
        )
    }

    private static func render(
        original: UIImage,
        edits proposedEdits: PostComposerPhotoEdits,
        maxPixelSize: CGFloat
    ) throws -> UIImage {
        var edits = proposedEdits
        edits.normalize()
        guard var result = normalizeOrientationAndResize(original, maxPixelSize: maxPixelSize) else {
            throw PostPhotoImportError.decodeFailed
        }

        result = transform(
            result,
            quarterTurns: edits.rotationQuarterTurns,
            straightenDegrees: edits.straightenDegrees,
            flipHorizontal: edits.flipHorizontal,
            flipVertical: edits.flipVertical
        )

        let crop = edits.crop
        let pixelWidth = CGFloat(result.cgImage?.width ?? Int(result.size.width))
        let pixelHeight = CGFloat(result.cgImage?.height ?? Int(result.size.height))
        let cropRect = CGRect(
            x: crop.normalizedX * pixelWidth,
            y: crop.normalizedY * pixelHeight,
            width: crop.normalizedWidth * pixelWidth,
            height: crop.normalizedHeight * pixelHeight
        ).integral.intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        guard !cropRect.isEmpty, let cropped = result.cgImage?.cropping(to: cropRect) else {
            throw PostPhotoImportError.decodeFailed
        }
        result = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        return applyAdjustments(edits.adjustments, to: result) ?? result
    }

    static func normalizeOrientationAndResize(_ image: UIImage, maxPixelSize: CGFloat) -> UIImage? {
        let orientedSize = image.size
        guard orientedSize.width > 0, orientedSize.height > 0 else { return nil }
        let scale = min(1, maxPixelSize / max(orientedSize.width, orientedSize.height))
        let target = CGSize(
            width: max(1, floor(orientedSize.width * scale)),
            height: max(1, floor(orientedSize.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func transform(
        _ image: UIImage,
        quarterTurns: Int,
        straightenDegrees: Double,
        flipHorizontal: Bool,
        flipVertical: Bool
    ) -> UIImage {
        let radians = CGFloat(quarterTurns) * (.pi / 2) + CGFloat(straightenDegrees) * (.pi / 180)
        var transform = CGAffineTransform(rotationAngle: radians)
        transform = transform.scaledBy(
            x: flipHorizontal ? -1 : 1,
            y: flipVertical ? -1 : 1
        )
        let sourceRect = CGRect(origin: .zero, size: image.size)
        let bounds = sourceRect.applying(transform).standardized
        let outputSize = CGSize(width: max(1, bounds.width), height: max(1, bounds.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.concatenate(transform)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }

    private static func applyAdjustments(
        _ adjustments: PostComposerPhotoAdjustments,
        to image: UIImage
    ) -> UIImage? {
        guard !adjustments.isNeutral, let input = CIImage(image: image) else { return image }
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(input, forKey: kCIInputImageKey)
        controls?.setValue(adjustments.brightness * 0.35, forKey: kCIInputBrightnessKey)
        controls?.setValue(1 + adjustments.contrast, forKey: kCIInputContrastKey)
        controls?.setValue(1 + adjustments.saturation, forKey: kCIInputSaturationKey)
        guard var output = controls?.outputImage else { return nil }

        if adjustments.warmth != 0 {
            let temperature = CIFilter(name: "CITemperatureAndTint")
            temperature?.setValue(output, forKey: kCIInputImageKey)
            temperature?.setValue(
                CIVector(x: CGFloat(6_500 - adjustments.warmth * 2_000), y: 0),
                forKey: "inputNeutral"
            )
            temperature?.setValue(CIVector(x: 6_500, y: 0), forKey: "inputTargetNeutral")
            output = temperature?.outputImage ?? output
        }

        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}

private enum UTTypeConformance {
    static func conformsToImage(_ uti: String) -> Bool {
        UTType(uti)?.conforms(to: .image) == true
    }
}
