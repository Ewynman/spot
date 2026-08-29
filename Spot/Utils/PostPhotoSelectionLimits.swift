//
//  PostPhotoSelectionLimits.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Composer-time photo count limits and capacity copy (separate from publish entitlement).
enum PostPhotoSelectionLimits {
    static func maxPhotoCount(isPro: Bool) -> Int {
        isPro ? Constants.PostLimits.maxProPostImages : Constants.PostLimits.maxFreePostImages
    }

    static func remainingCapacity(maxCount: Int, selectedCount: Int) -> Int {
        max(0, maxCount - selectedCount)
    }

    static func remainingCapacityText(maxCount: Int, selectedCount: Int) -> String {
        let remaining = remainingCapacity(maxCount: maxCount, selectedCount: selectedCount)
        return remaining == 1
            ? "You can add 1 more photo."
            : "You can add \(remaining) more photos."
    }

    static func galleryPickerMaxSelectionCount(
        modeIsReplace: Bool,
        maxCount: Int,
        selectedCount: Int
    ) -> Int {
        if modeIsReplace { return 1 }
        return max(1, maxCount - selectedCount)
    }

    static func overflowMessage(maxCount: Int) -> String {
        "You can add up to \(maxCount) photos."
    }

    static func acceptedPrefixCount(importedCount: Int, maxCount: Int, selectedCount: Int) -> Int {
        min(importedCount, remainingCapacity(maxCount: maxCount, selectedCount: selectedCount))
    }
}

/// Active-ID repair and reorder index math for the photo composer.
enum PostPhotoSelectionState {
    static func repairedActiveID(photos: [UUID], current: UUID?) -> UUID? {
        guard !photos.isEmpty else { return nil }
        if let current, photos.contains(current) { return current }
        return photos.first
    }

    /// After removing at `removedIndex`, which ID should become active.
    static func nextActiveIDAfterRemoval(remaining: [UUID], removedIndex: Int) -> UUID? {
        guard !remaining.isEmpty else { return nil }
        return remaining[min(removedIndex, remaining.count - 1)]
    }

    static func undoInsertIndex(savedIndex: Int, currentCount: Int) -> Int {
        min(savedIndex, currentCount)
    }

    static func clampedMoveDestination(source: Int, offset: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, source + offset), count - 1)
    }
}

/// Active photo preview height from aspect ratio and container width.
enum PostPhotoPreviewLayout {
    static func height(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        containerWidth: CGFloat,
        horizontalInset: CGFloat = 48,
        minHeight: CGFloat = 230,
        maxHeight: CGFloat = 390,
        fallback: CGFloat = 300
    ) -> CGFloat {
        guard imageWidth > 0, imageHeight > 0 else { return fallback }
        let ratio = imageWidth / max(imageHeight, 1)
        return min(maxHeight, max(minHeight, (containerWidth - horizontalInset) / ratio))
    }
}
