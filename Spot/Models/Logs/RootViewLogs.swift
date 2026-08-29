//
//  RootViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum RootViewLogs: SpotLog {
    case receivedCustomSchemeUrl
    case universalLinkWithoutWebpageUrl
    case receivedUniversalLink

    var tag: String { "RootView" }
    var level: LogLevel {
        switch self {
        case .receivedCustomSchemeUrl: return .info
        case .universalLinkWithoutWebpageUrl: return .debug
        case .receivedUniversalLink: return .info
        }
    }
    var message: String {
        switch self {
        case .receivedCustomSchemeUrl: return "Received custom scheme URL"
        case .universalLinkWithoutWebpageUrl: return "Universal link without webpage URL"
        case .receivedUniversalLink: return "Received Universal Link"
        }
    }
}
