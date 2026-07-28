//
//  SpotApp.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import SwiftUI
import FirebaseCrashlytics
import UIKit

@main
struct SpotApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var deepLinkState = DeepLinkState.shared
    @State private var showLaunchScreen = true

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        DebugKeychainReset.performIfRequested()
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        configureGlobalBackButtonAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchView()
                        .onAppear {
                            #if DEBUG
                            let delay: TimeInterval = SpotLaunchConfiguration.isUITestMode ? 0.05 : 1.5
                            let animationDuration: TimeInterval = SpotLaunchConfiguration.isUITestMode ? 0.01 : 0.5
                            #else
                            let delay: TimeInterval = 1.5
                            let animationDuration: TimeInterval = 0.5
                            #endif
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                withAnimation(.easeInOut(duration: animationDuration)) {
                                    showLaunchScreen = false
                                }
                            }
                        }
                } else {
                    RootView()
                        .environmentObject(authViewModel)
                        .environmentObject(deepLinkState)
                        .environmentObject(PermissionManager.shared)
                        .task {
                            SubscriptionManager.shared.startTransactionUpdatesListener { [weak authViewModel] appAccountToken, expirationDate in
                                guard let authViewModel,
                                      let userId = authViewModel.userId,
                                      let currentToken = UUID(uuidString: userId),
                                      appAccountToken == currentToken
                                else { return }
                                await authViewModel.setProActive(true, proUntil: expirationDate)
                            }
                            _ = await FreshInstallDetector.shared.handleFreshInstall()
                            deepLinkState.processPendingDeepLinks()
                        }
                }
            }
        }
    }
}

private extension SpotApp {
    func configureGlobalBackButtonAppearance() {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let backImage = UIImage(systemName: "chevron.left", withConfiguration: imageConfig)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "#F5F3EF"))
        appearance.shadowColor = .clear
        appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = UIColor(Color(hex: "#1D2C24"))

        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(
            UIOffset(horizontal: -1000, vertical: 0),
            for: .default
        )
    }
}
