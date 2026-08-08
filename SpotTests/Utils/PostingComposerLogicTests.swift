import Foundation
import Testing
@testable import Spot

struct PostEntitlementGuardTests {
    @Test func freeUserCannotExceedImageCap() {
        let message = PostEntitlementGuard.message(isPro: false, imageCount: 2, vibeCount: 1)
        #expect(message == Constants.PostLimits.freeMultipleImagesMessage)
    }

    @Test func proUserCannotExceedImageCap() {
        let message = PostEntitlementGuard.message(
            isPro: true,
            imageCount: Constants.PostLimits.maxProPostImages + 1,
            vibeCount: 1
        )
        #expect(message == Constants.PostLimits.proTooManyImagesMessage)
    }

    @Test func freeUserCannotExceedVibeCap() {
        let message = PostEntitlementGuard.message(isPro: false, imageCount: 1, vibeCount: 2)
        #expect(message == Constants.PostLimits.freeMultipleVibesMessage)
    }

    @Test func withinLimitsReturnsNil() {
        #expect(PostEntitlementGuard.message(isPro: false, imageCount: 1, vibeCount: 1) == nil)
        #expect(
            PostEntitlementGuard.message(
                isPro: true,
                imageCount: Constants.PostLimits.maxProPostImages,
                vibeCount: Constants.PostLimits.maxProPostVibes
            ) == nil
        )
    }
}

struct VibeSelectionPolicyTests {
    @Test func deselectRemovesVibe() {
        let outcome = VibeSelectionPolicy.toggle(
            current: ["Chill", "Hidden Gem"],
            vibe: "Chill",
            isPro: true,
            maxVibes: 5
        )
        #expect(outcome.selectedVibes == ["Hidden Gem"])
        #expect(outcome.didChange)
    }

    @Test func freeUserReplacesSelectionAndSurfacesUpsellWhenAlreadySelected() {
        let outcome = VibeSelectionPolicy.toggle(
            current: ["Chill"],
            vibe: "Cozy",
            isPro: false,
            maxVibes: 1
        )
        #expect(outcome.selectedVibes == ["Cozy"])
        #expect(outcome.validationMessage == Constants.PostLimits.freeMultipleVibesMessage)
    }

    @Test func proUserBlockedAtCap() {
        let current = ["A", "B", "C", "D", "E"]
        let outcome = VibeSelectionPolicy.toggle(
            current: current,
            vibe: "F",
            isPro: true,
            maxVibes: 5
        )
        #expect(outcome.selectedVibes == current)
        #expect(outcome.didChange == false)
        #expect(outcome.validationMessage == Constants.PostLimits.proTooManyVibesMessage)
    }
}

struct PostPhotoSelectionLimitsTests {
    @Test func tierCapsAndCopy() {
        #expect(PostPhotoSelectionLimits.maxPhotoCount(isPro: false) == Constants.PostLimits.maxFreePostImages)
        #expect(PostPhotoSelectionLimits.maxPhotoCount(isPro: true) == Constants.PostLimits.maxProPostImages)
        #expect(PostPhotoSelectionLimits.remainingCapacityText(maxCount: 5, selectedCount: 4) == "You can add 1 more photo.")
        #expect(PostPhotoSelectionLimits.remainingCapacityText(maxCount: 5, selectedCount: 2) == "You can add 3 more photos.")
        #expect(PostPhotoSelectionLimits.galleryPickerMaxSelectionCount(modeIsReplace: true, maxCount: 5, selectedCount: 2) == 1)
        #expect(PostPhotoSelectionLimits.galleryPickerMaxSelectionCount(modeIsReplace: false, maxCount: 5, selectedCount: 3) == 2)
        #expect(PostPhotoSelectionLimits.acceptedPrefixCount(importedCount: 4, maxCount: 5, selectedCount: 3) == 2)
    }
}

struct PostPhotoSelectionStateTests {
    @Test func repairsActiveID() {
        let a = UUID()
        let b = UUID()
        #expect(PostPhotoSelectionState.repairedActiveID(photos: [], current: a) == nil)
        #expect(PostPhotoSelectionState.repairedActiveID(photos: [a, b], current: nil) == a)
        #expect(PostPhotoSelectionState.repairedActiveID(photos: [a, b], current: b) == b)
        #expect(PostPhotoSelectionState.repairedActiveID(photos: [a, b], current: UUID()) == a)
    }

    @Test func removalAndMoveMath() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        #expect(PostPhotoSelectionState.nextActiveIDAfterRemoval(remaining: [b, c], removedIndex: 0) == b)
        #expect(PostPhotoSelectionState.nextActiveIDAfterRemoval(remaining: [a, c], removedIndex: 2) == c)
        #expect(PostPhotoSelectionState.undoInsertIndex(savedIndex: 5, currentCount: 2) == 2)
        #expect(PostPhotoSelectionState.clampedMoveDestination(source: 1, offset: -5, count: 3) == 0)
        #expect(PostPhotoSelectionState.clampedMoveDestination(source: 1, offset: 5, count: 3) == 2)
    }
}

struct PostPhotoPreviewLayoutTests {
    @Test func clampsPreviewHeight() {
        let tall = PostPhotoPreviewLayout.height(imageWidth: 100, imageHeight: 400, containerWidth: 390)
        #expect(tall == 390)
        let wide = PostPhotoPreviewLayout.height(imageWidth: 400, imageHeight: 100, containerWidth: 390)
        #expect(wide == 230)
    }
}
