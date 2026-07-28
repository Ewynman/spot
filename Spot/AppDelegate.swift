//
//  AppDelegate.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import UIKit
import FirebaseCore
import FirebaseCrashlytics
import FirebaseAnalytics
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    private var memoryWarningObserver: NSObjectProtocol?

    func applicationDidBecomeActive(_ application: UIApplication) {
        LoggingConfig.applyFromUserDefaults()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LoggingConfig.configure()
        SpotLogger.log(AppDelegateLogs.appLaunched)

        // Skip Firebase initialisation during unit tests – GoogleService-Info.plist
        // is not present in the repository and FirebaseApp.configure() would abort.
        if !SpotLaunchConfiguration.isUnitTestMode {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
                Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
                #if !DEBUG
                Analytics.setAnalyticsCollectionEnabled(true)
                #endif
            } else {
                SpotLogger.log(AppDelegateLogs.firebaseConfigurationMissing)
            }
        }

        // Register notification categories and set delegate
        Task { @MainActor in
            NotificationService.shared.registerNotificationCategories()
        }
        UNUserNotificationCenter.current().delegate = self

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            ImageService.shared.clearCache()
            RemoteImageMemory.clearCache()
            URLCache.shared.removeAllCachedResponses()
            Task { await MapViewportLoader.shared.clearCache() }
            SpotLogger.log(AppDelegateLogs.memoryWarning)
        }

        return true
    }

    // MARK: - Deep Link & URL Handling

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            SpotLogger.log(AppDelegateLogs.universalLinkOnLaunch)
            DeepLinkState.shared.handleInitialUserActivity(userActivity)
            return true
        }
        return false
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        SpotLogger.log(AppDelegateLogs.customSchemeUrlOnLaunch, details: ["url": url.absoluteString])
        DeepLinkState.shared.handleDeepLink(url, origin: .customScheme, isColdStart: true)
        return true
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, and badge even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap/action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        SpotLogger.log(AppDelegateLogs.notificationActionReceived, details: [
            "action": actionIdentifier,
            "type": userInfo["type"] as? String ?? "unknown"
        ])
        
        // Handle notification actions
        switch actionIdentifier {
        case NotificationService.NotificationAction.acceptFollowRequest.rawValue:
            handleAcceptFollowRequest(userInfo: userInfo)
        case NotificationService.NotificationAction.viewFollowRequest.rawValue:
            handleViewFollowRequests()
        case NotificationService.NotificationAction.viewProfile.rawValue:
            handleViewProfile(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            handleDefaultNotificationTap(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Notification Action Handlers
    
    private func handleAcceptFollowRequest(userInfo: [AnyHashable: Any]) {
        guard let requesterUid = userInfo["requester_uid"] as? String else { return }
        
        Task { @MainActor in
            // Navigate to follow requests and auto-accept
            NotificationCenter.default.post(
                name: .navigateToFollowRequestsAndAccept,
                object: nil,
                userInfo: ["requester_uid": requesterUid]
            )
        }
    }
    
    private func handleViewFollowRequests() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .navigateToFollowRequests, object: nil)
        }
    }
    
    private func handleViewProfile(userInfo: [AnyHashable: Any]) {
        guard let userId = userInfo["acceptor_uid"] as? String ?? userInfo["requester_uid"] as? String else { return }
        
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .navigateToProfile,
                object: nil,
                userInfo: ["user_id": userId]
            )
        }
    }
    
    private func handleDefaultNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "follow_request":
            handleViewFollowRequests()
        case "follow_accepted":
            handleViewProfile(userInfo: userInfo)
        default:
            break
        }
    }
}
