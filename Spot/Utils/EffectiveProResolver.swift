//
//  EffectiveProResolver.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum EffectiveProResolver {
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseProUntil(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = iso8601Fractional.date(from: raw) { return d }
        if let d = iso8601Plain.date(from: raw) { return d }
        return nil
    }

    /// Same rule as profile: explicit `pro_until` in the future wins; otherwise `is_pro`.
    static func effectiveIsPro(isPro: Bool, proUntilRaw: String?) -> Bool {
        if let until = parseProUntil(proUntilRaw) {
            return until > Date()
        }
        return isPro
    }
}
