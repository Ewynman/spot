//
//  SpotUserActionTracking.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

typealias SpotUserActionTracking = @Sendable (String, String, String) async -> Void

enum SpotAnalyticsBridge {
    static let trackUserAction: SpotUserActionTracking = { action, contentType, contentId in
        await MainActor.run {
            AnalyticsService.shared.trackUserAction(action, contentType: contentType, contentId: contentId)
        }
    }
}
