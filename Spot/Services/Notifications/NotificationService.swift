//
//  NotificationService.swift
//  Spot
//
//  Local notification delivery for social events (follow requests, follow accepts).
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Notification Categories
    
    enum NotificationCategory: String {
        case followRequest = "FOLLOW_REQUEST"
        case followAccepted = "FOLLOW_ACCEPTED"
    }
    
    // MARK: - Notification Actions
    
    enum NotificationAction: String {
        case acceptFollowRequest = "ACCEPT_FOLLOW_REQUEST"
        case viewFollowRequest = "VIEW_FOLLOW_REQUEST"
        case viewProfile = "VIEW_PROFILE"
    }
    
    // MARK: - Setup
    
    /// Registers notification categories and actions. Call once at app launch.
    func registerNotificationCategories() {
        let acceptAction = UNNotificationAction(
            identifier: NotificationAction.acceptFollowRequest.rawValue,
            title: "Accept",
            options: [.foreground]
        )
        
        let viewFollowRequestAction = UNNotificationAction(
            identifier: NotificationAction.viewFollowRequest.rawValue,
            title: "View",
            options: [.foreground]
        )
        
        let viewProfileAction = UNNotificationAction(
            identifier: NotificationAction.viewProfile.rawValue,
            title: "View Profile",
            options: [.foreground]
        )
        
        let followRequestCategory = UNNotificationCategory(
            identifier: NotificationCategory.followRequest.rawValue,
            actions: [acceptAction, viewFollowRequestAction],
            intentIdentifiers: [],
            options: []
        )
        
        let followAcceptedCategory = UNNotificationCategory(
            identifier: NotificationCategory.followAccepted.rawValue,
            actions: [viewProfileAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            followRequestCategory,
            followAcceptedCategory
        ])
    }
    
    // MARK: - Notification Delivery
    
    /// Sends a local notification when a user receives a follow request.
    /// - Parameters:
    ///   - username: The username of the person who sent the follow request
    ///   - requesterUid: The user ID of the requester
    func notifyFollowRequestReceived(from username: String, requesterUid: String) {
        Task {
            let status = await getNotificationAuthorizationStatus()
            guard status == .authorized else {
                SpotLogger.log(NotificationServiceLogs.notificationSkippedNotAuthorized, details: [
                    "type": "follow_request_received",
                    "requester": username
                ])
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "New Follow Request"
            content.body = "\(username) wants to follow you"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.followRequest.rawValue
            content.userInfo = [
                "type": "follow_request",
                "requester_uid": requesterUid,
                "username": username
            ]
            
            let request = UNNotificationRequest(
                identifier: "follow_request_\(requesterUid)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil // Immediate delivery
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                SpotLogger.log(NotificationServiceLogs.notificationSent, details: [
                    "type": "follow_request_received",
                    "requester": username
                ])
            } catch {
                SpotLogger.log(NotificationServiceLogs.notificationFailed, details: [
                    "type": "follow_request_received",
                    "requester": username,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    /// Sends a local notification when a follow request is accepted.
    /// - Parameters:
    ///   - username: The username of the person who accepted the request
    ///   - acceptorUid: The user ID of the person who accepted
    func notifyFollowRequestAccepted(by username: String, acceptorUid: String) {
        Task {
            let status = await getNotificationAuthorizationStatus()
            guard status == .authorized else {
                SpotLogger.log(NotificationServiceLogs.notificationSkippedNotAuthorized, details: [
                    "type": "follow_request_accepted",
                    "acceptor": username
                ])
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Follow Request Accepted"
            content.body = "\(username) accepted your follow request"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.followAccepted.rawValue
            content.userInfo = [
                "type": "follow_accepted",
                "acceptor_uid": acceptorUid,
                "username": username
            ]
            
            let request = UNNotificationRequest(
                identifier: "follow_accepted_\(acceptorUid)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil // Immediate delivery
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                SpotLogger.log(NotificationServiceLogs.notificationSent, details: [
                    "type": "follow_request_accepted",
                    "acceptor": username
                ])
            } catch {
                SpotLogger.log(NotificationServiceLogs.notificationFailed, details: [
                    "type": "follow_request_accepted",
                    "acceptor": username,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}

// MARK: - Logging

enum NotificationServiceLogs: SpotLog {
    case notificationSent
    case notificationFailed
    case notificationSkippedNotAuthorized
    case notificationActionHandled

    var tag: String { "NotificationService" }

    var level: LogLevel {
        switch self {
        case .notificationFailed: return .error
        case .notificationSent, .notificationSkippedNotAuthorized, .notificationActionHandled: return .info
        }
    }

    var message: String {
        switch self {
        case .notificationSent: return "Local notification sent"
        case .notificationFailed: return "Local notification failed"
        case .notificationSkippedNotAuthorized: return "Notification skipped: not authorized"
        case .notificationActionHandled: return "Notification action handled"
        }
    }
}
