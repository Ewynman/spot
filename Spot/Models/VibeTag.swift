//
//  VibeTag.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

struct VibeTag: Identifiable, Codable, Hashable {
    var id: String?
    let name: String
    let name_lower: String?
    let createdAt: Date?
}
