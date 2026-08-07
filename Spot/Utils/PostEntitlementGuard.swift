import Foundation

/// Client-side post publish entitlement messages aligned with server RPC limits.
enum PostEntitlementGuard {
    static func message(
        isPro: Bool,
        imageCount: Int,
        vibeCount: Int
    ) -> String? {
        let maxImg = isPro ? Constants.PostLimits.maxProPostImages : Constants.PostLimits.maxFreePostImages
        let maxVib = isPro ? Constants.PostLimits.maxProPostVibes : Constants.PostLimits.maxFreePostVibes
        if imageCount > maxImg {
            return isPro ? Constants.PostLimits.proTooManyImagesMessage : Constants.PostLimits.freeMultipleImagesMessage
        }
        if vibeCount > maxVib {
            return isPro ? Constants.PostLimits.proTooManyVibesMessage : Constants.PostLimits.freeMultipleVibesMessage
        }
        return nil
    }
}
