//
//  PostgresErrorDigest.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum PostgresErrorDigest {
    /// `unique_violation` (SQLSTATE 23505) or duplicate-key wording from PostgREST.
    static func isLikelyUniqueViolation(_ error: Error) -> Bool {
        let blob = String(describing: error) + " " + error.localizedDescription
        if blob.contains("23505") { return true }
        if blob.range(of: "duplicate key", options: .caseInsensitive) != nil { return true }
        return false
    }
}
