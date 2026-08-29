//
//  Place.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

struct Place: Identifiable, Codable {
    var id: String?
    var name: String
    var name_lower: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var createdAt: Date?
    var createdBy: String?
    var postsCount: Int?
}
