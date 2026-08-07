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
