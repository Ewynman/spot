//
//  ModerationPolicy.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

struct ModerationPolicy {
    /// Matches default `spot_image` thresholds in `supabase/functions/moderate-image` (Azure 0/2/4/6 scale).
    static let sexualBlockAt: Int = 4
    static let violenceBlockAt: Int = 4
    static let hateBlockAt: Int = 4
    static let selfHarmBlockAt: Int = 4

    /// Evaluate Azure-like severity scores map and decide if approved
    /// - Parameter scores: map of category->severity (0-7 or similar). Keys are case/format agnostic.
    /// - Returns: (approved, reason); reason examples: "over_threshold:sexual", "over_threshold:violence"
    static func evaluate(scores: [String: Any]?) -> (approved: Bool, reason: String?) {
        guard let scores else { return (false, "missing_scores") }
        // Normalize keys -> lowercased alphanumerics
        func norm(_ s: String) -> String {
            return s.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
        }
        var lowered: [String: Int] = [:]
        for (k, v) in scores {
            let key = norm(k)
            if let i = v as? Int { lowered[key] = i } else if let d = v as? Double { lowered[key] = Int(d.rounded()) } else if let s = v as? String, let i = Int(s) { lowered[key] = i }
        }

        func over(_ keys: [String], _ limit: Int) -> Bool {
            for k in keys {
                if let val = lowered[k], val >= limit { return true }
            }
            return false
        }

        if over(["sexual", "sex", "adult"], sexualBlockAt) { return (false, "over_threshold:sexual") }
        if over(["violence", "violent"], violenceBlockAt) { return (false, "over_threshold:violence") }
        if over(["hate", "hatespeech"], hateBlockAt) { return (false, "over_threshold:hate") }
        if over(["selfharm", "selfinjury"], selfHarmBlockAt) { return (false, "over_threshold:selfharm") }
        return (true, nil)
    }
}
