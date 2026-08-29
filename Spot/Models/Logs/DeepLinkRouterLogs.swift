//
//  DeepLinkRouterLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum DeepLinkRouterLogs: SpotLog {
    case parsingUrl
    case unknownUrlScheme
    case parsedUniversalLinkForSpot
    case invalidSpotIdInUniversalLink
    case invalidUniversalLinkPath
    case customSchemeParsing
    case parsedCustomSchemeHostVariant
    case invalidSpotIdCustomSchemeHost
    case parsedCustomSchemePathVariant
    case invalidSpotIdCustomSchemePath
    case parsedCustomSchemeQueryVariant
    case invalidSpotIdCustomSchemeQuery
    case parsedCustomSchemeSubscriptionReturn
    case invalidCustomScheme
    case routeSuccess
    case routeFailure

    var tag: String { "DeepLinkRouter" }
    var level: LogLevel {
        switch self {
        case .parsingUrl: return .debug
        case .unknownUrlScheme: return .debug
        case .parsedUniversalLinkForSpot: return .info
        case .invalidSpotIdInUniversalLink: return .debug
        case .invalidUniversalLinkPath: return .debug
        case .customSchemeParsing: return .debug
        case .parsedCustomSchemeHostVariant: return .info
        case .invalidSpotIdCustomSchemeHost: return .debug
        case .parsedCustomSchemePathVariant: return .info
        case .invalidSpotIdCustomSchemePath: return .debug
        case .parsedCustomSchemeQueryVariant: return .info
        case .invalidSpotIdCustomSchemeQuery: return .debug
        case .parsedCustomSchemeSubscriptionReturn: return .info
        case .invalidCustomScheme: return .debug
        case .routeSuccess: return .info
        case .routeFailure: return .error
        }
    }
    var message: String {
        switch self {
        case .parsingUrl: return "Parsing URL"
        case .unknownUrlScheme: return "Unknown URL scheme"
        case .parsedUniversalLinkForSpot: return "Parsed Universal Link for spot"
        case .invalidSpotIdInUniversalLink: return "Invalid spot ID in Universal Link"
        case .invalidUniversalLinkPath: return "Invalid Universal Link path"
        case .customSchemeParsing: return "Custom scheme parsing"
        case .parsedCustomSchemeHostVariant: return "Parsed Custom Scheme (host variant) for spot"
        case .invalidSpotIdCustomSchemeHost: return "Invalid spot ID in Custom Scheme (host variant)"
        case .parsedCustomSchemePathVariant: return "Parsed Custom Scheme (path variant) for spot"
        case .invalidSpotIdCustomSchemePath: return "Invalid spot ID in Custom Scheme (path variant)"
        case .parsedCustomSchemeQueryVariant: return "Parsed Custom Scheme (query variant) for spot"
        case .invalidSpotIdCustomSchemeQuery: return "Invalid spot ID in Custom Scheme (query variant)"
        case .parsedCustomSchemeSubscriptionReturn: return "Parsed Custom Scheme for subscription return"
        case .invalidCustomScheme: return "Invalid Custom Scheme"
        case .routeSuccess: return "Deep link route success"
        case .routeFailure: return "Deep link route failure"
        }
    }
}
