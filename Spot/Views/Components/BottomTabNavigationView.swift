//
//  BottomTabNavigationView.swift
//  Spot
//
//  Created By Wynman, Edward (Current date)
//

import SwiftUI

/// Dedicated Post tab: wraps the full post flow. After queueing a publish, switches to Home; completion toast comes from `SpotPublishCoordinator` + feed refresh on `.spotDidPostSuccess`.
private struct PostTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        PostFlowView(onPostQueued: { selectedTab = 0 })
    }
}

private struct PublishBannerView: View {
    let title: String
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView(value: progress, total: 1)
                .progressViewStyle(.linear)
                .tint(Constants.Colors.primary)
                .scaleEffect(x: 1, y: 0.8, anchor: .center)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Constants.Colors.primary.opacity(0.12))
                        .frame(height: 4)
                        .offset(y: 1)
                )
                .clipShape(Capsule())
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 4)
                }
                .frame(height: 8)
            }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Constants.Colors.background)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct BottomTabNavigationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var permissionManager: PermissionManager
    @ObservedObject private var spotPublishCoordinator = SpotPublishCoordinator.shared
    @StateObject private var firstRunOnboarding = SpotFirstRunOnboardingManager()
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var selectedTab: Int = 0
    @State private var coachFrames: [CoachTarget: CGRect] = [:]
    /// Pre-permission sheet for the first-run map tour step (`.userLocation`).
    @State private var showTourLocationPrePrompt = false
    /// Notification permission sheet shown after onboarding tour completes.
    @State private var showNotificationPermissionPrompt = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Page content for selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        HomepageView()
                    case 1:
                        MapView(spots: [])
                            .environmentObject(authVM)
                    case 2:
                        PostTabView(selectedTab: $selectedTab)
                    case 3:
                        SearchView()
                            .environmentObject(authVM)
                    case 4:
                        ProfileView(
                            userId: nil,
                            fromNavigationPush: false,
                            viewModel: profileViewModel
                        )
                            .environmentObject(authVM)
                    default:
                        HomepageView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom bottom bar (same design as before: built into page, not system tab bar)
                HStack(spacing: 0) {
                    Button(action: { selectTab(0) }) {
                        BottomNavItem(icon: "house.fill", title: "Home", isSelected: selectedTab == 0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("navigation.homeTab")

                    Button(action: { selectTab(1) }) {
                        BottomNavItem(icon: "map.fill", title: "Map", isSelected: selectedTab == 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .measure(target: .mapTab)
                    .accessibilityIdentifier("navigation.mapTab")

                    Button(action: { selectTab(2) }) {
                        BottomNavItem(icon: "plus.square.fill", title: "Post", isSelected: selectedTab == 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("navigation.postTab")

                    Button(action: { selectTab(3) }) {
                        BottomNavItem(icon: "magnifyingglass", title: "Search", isSelected: selectedTab == 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("navigation.searchTab")

                    Button(action: { selectTab(4) }) {
                        BottomNavItem(icon: "person.fill", title: "Profile", isSelected: selectedTab == 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("navigation.profileTab")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Constants.Colors.background)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1),
                    alignment: .top
                )
            }
            .ignoresSafeArea(.keyboard)

            VStack(spacing: 8) {
                if spotPublishCoordinator.bannerPhase != .hidden {
                    PublishBannerView(
                        title: spotPublishCoordinator.bannerTitle,
                        progress: spotPublishCoordinator.publishProgress.fraction
                    )
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if spotPublishCoordinator.showToast {
                    ToastView(message: spotPublishCoordinator.toastMessage, isError: spotPublishCoordinator.toastIsError)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: spotPublishCoordinator.bannerPhase)
            .animation(.easeInOut(duration: 0.2), value: spotPublishCoordinator.showToast)

            SpotFirstRunOnboardingOverlay(
                manager: firstRunOnboarding,
                targetRect: currentTourTargetRect,
                onPrimary: handleOnboardingPrimaryAction,
                onBack: handleOnboardingBack,
                onSkip: handleOnboardingSkip
            )
        }
        .onPreferenceChange(CoachFramesPrefKey.self) { coachFrames = $0 }
        .onAppear(perform: evaluateFirstRunOnboarding)
        .onChange(of: authVM.isAuthenticated) { _, _ in evaluateFirstRunOnboarding() }
        .onChange(of: authVM.userId) { _, _ in evaluateFirstRunOnboarding() }
        .onChange(of: authVM.likedSpots) { _, _ in evaluateFirstRunOnboarding() }
        .onChange(of: authVM.bookmarkedSpots) { _, _ in evaluateFirstRunOnboarding() }
        .onReceive(NotificationCenter.default.publisher(for: .selectMainTab)) { output in
            guard let tab = output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int,
                  (0...4).contains(tab) else { return }
            selectTab(tab)
        }
        .sheet(isPresented: $showTourLocationPrePrompt) {
            LocationPermissionView(
                authDestination: .signup,
                showsBackButton: false,
                onComplete: {
                    showTourLocationPrePrompt = false
                    LocationManager.shared.requestCurrentLocationForMapTab()
                    if firstRunOnboarding.isPresented, firstRunOnboarding.currentStep == .userLocation {
                        firstRunOnboarding.next()
                    }
                }
            )
            .environmentObject(permissionManager)
        }
        .sheet(isPresented: $showNotificationPermissionPrompt) {
            NotificationPermissionView(
                authDestination: .signup,
                showsBackButton: false,
                onComplete: {
                    showNotificationPermissionPrompt = false
                }
            )
            .environmentObject(permissionManager)
        }
        .accessibilityIdentifier("main.tabShell")
    }

    private var currentTourTargetRect: CGRect? {
        guard let target = firstRunOnboarding.currentStep.target else { return nil }
        return coachFrames[target]
    }

    private func selectTab(_ tab: Int) {
        if tab == selectedTab {
            NotificationCenter.default.post(
                name: .mainTabReselectSame,
                object: nil,
                userInfo: [SpotMainTabNotification.userInfoTabIndexKey: tab]
            )
            return
        }
        selectedTab = tab
        if tab == 1 {
            firstRunOnboarding.mapTabSelected()
        }
    }

    private func evaluateFirstRunOnboarding() {
        let firstSessionCandidate = authVM.likedSpots.isEmpty && authVM.bookmarkedSpots.isEmpty
        // Only force Home during the active welcome overlay. `currentStep` defaults to
        // `.welcome` and stays that way for users who completed onboarding via migration
        // without advancing steps; pairing with `isPresented` avoids jumping Home on
        // every `likedSpots` / `bookmarkedSpots` change (e.g. liking from Map or Search).
        if selectedTab != 0, firstRunOnboarding.isPresented, firstRunOnboarding.currentStep == .welcome {
            selectedTab = 0
        }
        firstRunOnboarding.startIfNeeded(
            isAuthenticated: authVM.isAuthenticated,
            isFirstSessionCandidate: firstSessionCandidate,
            userId: authVM.userId
        )
    }

    private func handleOnboardingPrimaryAction() {
        switch firstRunOnboarding.currentStep {
        case .welcome:
            selectedTab = 0
            // Let the home feed begin loading so the first `SpotCard` can publish
            // coach geometry before the tour highlights the card step.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                firstRunOnboarding.startTour()
            }
        case .mapTab:
            selectedTab = 1
            firstRunOnboarding.mapTabSelected()
        case .userLocation:
            handleTourUserLocationContinue()
        case .finale:
            selectedTab = 0
            firstRunOnboarding.finish()
            // After onboarding finishes, request notification permissions
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                requestNotificationPermissionsAfterOnboarding()
            }
        default:
            firstRunOnboarding.next()
        }
    }

    /// Request notification permissions after the user completes onboarding.
    /// Only prompts if notifications are not yet determined.
    private func requestNotificationPermissionsAfterOnboarding() {
        permissionManager.updatePermissionStatuses()
        guard permissionManager.notificationStatus == .notDetermined else { return }
        showNotificationPermissionPrompt = true
    }

    private func handleOnboardingSkip() {
        firstRunOnboarding.skip()
        // After onboarding is skipped, request notification permissions
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            requestNotificationPermissionsAfterOnboarding()
        }
    }
    
    private func handleOnboardingBack() {
        if firstRunOnboarding.currentStep == .mapTab {
            selectedTab = 0
        }
        firstRunOnboarding.back()
    }

    /// First-run map tour: "Start from where you are" is the contextual moment
    /// to surface the Location pre-prompt (App Review 5.1.1 / 5.1.5).
    private func handleTourUserLocationContinue() {
        guard firstRunOnboarding.isPresented, firstRunOnboarding.currentStep == .userLocation else { return }
        guard selectedTab == 1 else {
            selectedTab = 1
            return
        }

        permissionManager.updatePermissionStatuses()
        // PermissionManager just read the system value. LocationManager's
        // published mirror can lag behind its separate CLLocationManager
        // delegate, which previously sent authorized users back through the
        // pre-prompt instead of requesting their location.
        switch permissionManager.locationStatus {
        case .notDetermined:
            showTourLocationPrePrompt = true
        case .authorizedAlways, .authorizedWhenInUse:
            LocationManager.shared.requestCurrentLocationForMapTab()
            firstRunOnboarding.next()
        case .denied, .restricted:
            firstRunOnboarding.next()
        @unknown default:
            firstRunOnboarding.next()
        }
    }
}

// MARK: - Previews

#Preview("Bottom tab navigation") {
    let auth = AuthViewModel()
    auth.isAuthenticated = true
    return BottomTabNavigationView()
        .environmentObject(auth)
        .environmentObject(PermissionManager.shared)
}

#Preview("Tab bar only") {
    struct TabBarOnlyPreview: View {
        @State private var selected: Int = 0
        var body: some View {
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { idx in
                        Button(action: { selected = idx }) {
                            BottomNavItem(
                                icon: ["house.fill", "map.fill", "plus.square.fill", "magnifyingglass", "person.fill"][idx],
                                title: ["Home", "Map", "Post", "Search", "Profile"][idx],
                                isSelected: selected == idx
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Constants.Colors.background)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1),
                    alignment: .top
                )
            }
        }
    }
    return TabBarOnlyPreview()
}
