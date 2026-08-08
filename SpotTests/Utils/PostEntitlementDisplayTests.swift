import Foundation
import Testing
@testable import Spot

@Suite("Pro post entitlements & card vibe display")
struct PostEntitlementDisplayTests {
    @Test func effectiveProUsesProUntilInFuture() {
        let far = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 365))
        #expect(EffectiveProResolver.effectiveIsPro(isPro: false, proUntilRaw: far))
    }

    @Test func visibleCardVibesShowsMultipleOnlyWhenAuthorPro() {
        let spotPro = Spot(
            id: "1",
            vibeTag: "A",
            vibeTags: ["A", "B"],
            authorIsPro: true
        )
        #expect(spotPro.visibleVibeLabelsForCard() == ["A", "B"])

        let spotFree = Spot(
            id: "2",
            vibeTag: "A",
            vibeTags: ["A", "B"],
            authorIsPro: false
        )
        #expect(spotFree.visibleVibeLabelsForCard() == ["A"])

        let unknown = Spot(id: "3", vibeTag: "A", vibeTags: ["A", "B"], authorIsPro: nil)
        #expect(unknown.visibleVibeLabelsForCard() == ["A"])
    }

    @Test func postLimitConstantsMatchPRD() {
        #expect(Constants.PostLimits.maxFreePostImages == 1)
        #expect(Constants.PostLimits.maxProPostImages == 5)
        #expect(Constants.PostLimits.maxFreePostVibes == 1)
        #expect(Constants.PostLimits.maxProPostVibes == 5)
    }
}
