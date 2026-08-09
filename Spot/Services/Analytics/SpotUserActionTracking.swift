import Foundation

typealias SpotUserActionTracking = @Sendable (String, String, String) async -> Void

enum SpotAnalyticsBridge {
    static let trackUserAction: SpotUserActionTracking = { action, contentType, contentId in
        await MainActor.run {
            AnalyticsService.shared.trackUserAction(action, contentType: contentType, contentId: contentId)
        }
    }
}
