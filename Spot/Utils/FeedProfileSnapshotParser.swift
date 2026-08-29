//
//  FeedProfileSnapshotParser.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Parses raw feed-profile RPC JSON for the algorithm debug screen.
enum FeedProfileSnapshotParser {
    struct Snapshot: Equatable {
        var profileVersion: Int?
        var lastComputedAt: Date?
        var prettyJSON: String
    }

    static func parse(_ data: Data) -> Snapshot {
        guard
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let row = arr.first
        else {
            return Snapshot(
                profileVersion: nil,
                lastComputedAt: nil,
                prettyJSON: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let version = row["profile_version"] as? Int
        var computed: Date?
        if let lc = row["last_computed_at"] as? String {
            computed = iso8601.date(from: lc) ?? iso8601Frac.date(from: lc)
        }

        let pretty: String
        if let prettyData = try? JSONSerialization.data(
            withJSONObject: row,
            options: [.prettyPrinted, .sortedKeys]
        ),
           let str = String(data: prettyData, encoding: .utf8) {
            pretty = str
        } else {
            pretty = String(data: data, encoding: .utf8) ?? ""
        }

        return Snapshot(profileVersion: version, lastComputedAt: computed, prettyJSON: pretty)
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let iso8601Frac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
