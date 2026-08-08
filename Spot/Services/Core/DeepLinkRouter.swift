//
//  DeepLinkRouter.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import Foundation
import UIKit

enum DeepLinkRoute {
    case spotDetail(spotId: String)
    case subscriptionReturn
    case unknown
}

enum DeepLinkOrigin {
    case universalLink
    case customScheme
}

struct DeepLinkAnalytics {
    let origin: DeepLinkOrigin
    let spotId: String?
    let appVersion: String
    let isColdStart: Bool
    let success: Bool
    let errorReason: String?
}

final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    private init() {}

    // MARK: - URL Parsing
    func parseURL(_ url: URL) -> DeepLinkRoute {
        SpotLogger.log(
            DeepLinkRouterLogs.parsingUrl,
            details: [
                "scheme": url.scheme ?? "nil",
                "host": url.host ?? "nil",
                "pathComponentCount": url.pathComponents.count
            ]
        )

        // Handle Universal Links (https://spotapp.online/s/:spotId, localhost for testing, or ngrok for DEBUG)
        if url.scheme == "https" && URLConfiguration.shared.isAllowedUniversalLinkHost(url.host ?? "") {
            return parseUniversalLink(url)
        }

        // Handle HTTP localhost for testing
        if url.scheme == "http" && url.host == "localhost" {
            return parseUniversalLink(url)
        }

        // Handle Custom Scheme (spotapp://spot/:spotId or spotapp://subscription/return)
        if url.scheme == "spotapp" {
            return parseCustomScheme(url)
        }

        SpotLogger.log(DeepLinkRouterLogs.unknownUrlScheme, details: ["scheme": url.scheme ?? "nil"])
        return .unknown
    }

    private func parseUniversalLink(_ url: URL) -> DeepLinkRoute {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Pattern: /s/:spotId
        if pathComponents.count == 2 && pathComponents[0] == "s" {
            let spotId = pathComponents[1]
            if isValidSpotId(spotId) {
                SpotLogger.log(DeepLinkRouterLogs.parsedUniversalLinkForSpot, details: ["spotId": spotId])
                return .spotDetail(spotId: spotId)
            } else {
                SpotLogger.log(DeepLinkRouterLogs.invalidSpotIdInUniversalLink, details: ["spotId": spotId])
            }
        }

        SpotLogger.log(DeepLinkRouterLogs.invalidUniversalLinkPath, details: ["path": url.path])
        return .unknown
    }

    private func parseCustomScheme(_ url: URL) -> DeepLinkRoute {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let host = url.host?.lowercased()

        SpotLogger.log(DeepLinkRouterLogs.customSchemeParsing, details: ["host": host ?? "nil", "pathComponents": pathComponents])

        // Pattern 1: spotapp://spot/:spotId (host = "spot", path = "/:spotId")
        if host == "spot" && pathComponents.count == 1 {
            let spotId = pathComponents[0]
            if isValidSpotId(spotId) {
                SpotLogger.log(DeepLinkRouterLogs.parsedCustomSchemeHostVariant, details: ["spotId": spotId])
                return .spotDetail(spotId: spotId)
            } else {
                SpotLogger.log(DeepLinkRouterLogs.invalidSpotIdCustomSchemeHost, details: ["spotId": spotId])
            }
        }

        // Pattern 2: spotapp:///spot/:spotId (host = nil, path = "/spot/:spotId")
        if host == nil && pathComponents.count == 2 && pathComponents[0].lowercased() == "spot" {
            let spotId = pathComponents[1]
            if isValidSpotId(spotId) {
                SpotLogger.log(DeepLinkRouterLogs.parsedCustomSchemePathVariant, details: ["spotId": spotId])
                return .spotDetail(spotId: spotId)
            } else {
                SpotLogger.log(DeepLinkRouterLogs.invalidSpotIdCustomSchemePath, details: ["spotId": spotId])
            }
        }

        // Pattern 3: spotapp://open?spotId=:spotId (query variant)
        if host == "open" || (host == nil && pathComponents.count == 1 && pathComponents[0].lowercased() == "open") {
            if let spotId = url.queryParameters?["spotId"] {
                if isValidSpotId(spotId) {
                    SpotLogger.log(DeepLinkRouterLogs.parsedCustomSchemeQueryVariant, details: ["spotId": spotId])
                    return .spotDetail(spotId: spotId)
                } else {
                    SpotLogger.log(DeepLinkRouterLogs.invalidSpotIdCustomSchemeQuery, details: ["spotId": spotId])
                }
            }
        }
        
        // Pattern 4: spotapp://subscription/return (subscription return)
        if host == "subscription" && pathComponents.count == 1 && pathComponents[0].lowercased() == "return" {
            SpotLogger.log(DeepLinkRouterLogs.parsedCustomSchemeSubscriptionReturn)
            return .subscriptionReturn
        }

        SpotLogger.log(DeepLinkRouterLogs.invalidCustomScheme, details: ["host": host ?? "nil", "path": url.path])
        return .unknown
    }

    private func isValidSpotId(_ spotId: String) -> Bool {
        // Basic validation: non-empty and reasonable length
        return !spotId.isEmpty && spotId.count <= 50 && spotId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
}

// MARK: - URL Extensions

extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }

        var items: [String: String] = [:]
        for queryItem in queryItems {
            items[queryItem.name] = queryItem.value
        }
        return items
    }
}

// MARK: - Analytics

extension DeepLinkRouter {
    func logDeepLinkEvent(origin: DeepLinkOrigin, spotId: String?, isColdStart: Bool, success: Bool, errorReason: String? = nil) {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        _ = DeepLinkAnalytics(
            origin: origin,
            spotId: spotId,
            appVersion: appVersion,
            isColdStart: isColdStart,
            success: success,
            errorReason: errorReason
        )

        if success {
            SpotLogger.log(DeepLinkRouterLogs.routeSuccess, details: ["origin": "\(origin)", "spotId": spotId ?? "nil", "coldStart": isColdStart])
        } else {
            SpotLogger.log(DeepLinkRouterLogs.routeFailure, details: ["origin": "\(origin)", "spotId": spotId ?? "nil", "reason": errorReason ?? "unknown"])
        }

        // Track deep link event
        let originString: String
        switch origin {
        case .universalLink:
            originString = "universal_link"
        case .customScheme:
            originString = "custom_scheme"
        }
        Task { @MainActor in
            AnalyticsService.shared.trackDeepLink(
                origin: originString,
                spotId: spotId,
                isColdStart: isColdStart,
                success: success,
                errorReason: errorReason
            )
        }
    }
}
