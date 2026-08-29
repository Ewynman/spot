//
//  SpotModelLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotModelLogs: SpotLog {
    case geocodingFailed
    case decodeFailed

    var tag: String { "Spot" }
    var level: LogLevel {
        switch self {
        case .geocodingFailed: return .error
        case .decodeFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .geocodingFailed: return "Geocoding failed for spot"
        case .decodeFailed: return "Failed to decode spot"
        }
    }
}
