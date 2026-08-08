//
//  AnalyticsService.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import Foundation
import FirebaseAnalytics

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}
    
    // MARK: - Event Tracking
    
    /// Log a custom event with parameters
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        var cleanParams: [String: Any]?
        
        if let params = parameters {
            cleanParams = [:]
            // Firebase Analytics only accepts String, Int, Double, Bool values
            for (key, value) in params {
                if let stringValue = value as? String {
                    cleanParams?[key] = stringValue
                } else if let intValue = value as? Int {
                    cleanParams?[key] = intValue
                } else if let doubleValue = value as? Double {
                    cleanParams?[key] = doubleValue
                } else if let boolValue = value as? Bool {
                    cleanParams?[key] = boolValue
                } else {
                    // Convert other types to string
                    cleanParams?[key] = String(describing: value)
                }
            }
        }
        
        Analytics.logEvent(name, parameters: cleanParams)
        SpotLogger.log(AnalyticsServiceLogs.eventTracked, details: (cleanParams ?? [:]).merging(["name": name]) { _, new in new })
    }
    
    // MARK: - User Properties
    
    /// Set a user property
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    /// Set user ID for analytics
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }
    
    // MARK: - Screen Tracking
    
    /// Track screen view
    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName
        ]
        if let screenClass = screenClass {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
    }
    
    // MARK: - Specific Event Helpers
    
    /// Track deep link event
    func trackDeepLink(origin: String, spotId: String?, isColdStart: Bool, success: Bool, errorReason: String? = nil) {
        var parameters: [String: Any] = [
            "origin": origin,
            "cold_start": isColdStart,
            "success": success
        ]
        
        if let spotId = spotId {
            parameters["spot_id"] = spotId
        }
        
        if let errorReason = errorReason {
            parameters["error_reason"] = errorReason
        }
        
        logEvent("deep_link_opened", parameters: parameters)
    }
    
    /// Track authentication events
    func trackAuthEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        let params = parameters ?? [:]
        logEvent(eventName, parameters: params)
    }
    
    /// Track permission request
    func trackPermissionRequest(type: String, action: String, result: String? = nil) {
        var parameters: [String: Any] = [
            "permission_type": type,
            "action": action
        ]
        
        if let result = result {
            parameters["result"] = result
        }
        
        logEvent(Constants.Analytics.permissionsRequested, parameters: parameters)
    }
    
    /// Track image load failure
    func trackImageLoadFailure(spotId: String?, urlHost: String?, errorCode: Int, attempt: Int) {
        var parameters: [String: Any] = [
            "error_code": errorCode,
            "attempt": attempt
        ]
        
        if let spotId = spotId {
            parameters["spot_id"] = spotId
        }
        
        if let urlHost = urlHost {
            parameters["url_host"] = urlHost
        }
        
        logEvent(Constants.Analytics.imageLoadFailed, parameters: parameters)
    }
    
    /// Track feed event
    func trackFeedEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        logEvent(eventName, parameters: parameters)
    }
    
    /// Track user action (like, save, post, etc.)
    func trackUserAction(_ action: String, contentType: String, contentId: String? = nil, parameters: [String: Any]? = nil) {
        var params = parameters ?? [:]
        params["content_type"] = contentType
        if let contentId = contentId {
            params["content_id"] = contentId
        }
        logEvent(action, parameters: params)
    }
}
