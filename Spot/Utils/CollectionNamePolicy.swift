//
//  CollectionNamePolicy.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Trimming / emptiness gate for creating a bookmark collection.
enum CollectionNamePolicy {
    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canCreate(_ raw: String) -> Bool {
        !normalized(raw).isEmpty
    }
}
