//
//  AnalyticsServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum AnalyticsServiceLogs: SpotLog {
    case eventTracked

    var tag: String { "AnalyticsService" }
    var level: LogLevel {
        switch self {
        case .eventTracked: return .debug
        }
    }
    var message: String {
        switch self {
        case .eventTracked: return "Analytics event tracked"
        }
    }
}
