//
//  ProfileView.swift
//  Spot
//
//  Created by Edward Wynman on 8/6/25.
//

import SwiftUI
import MapKit

enum ProfileSpotsEmptyState: Equatable {
    case ownProfile
    case otherProfile
    case privateProfile

    static func resolve(isOwnProfile: Bool, canViewContent: Bool) -> Self {
        if isOwnProfile {
            return .ownProfile
        }
        return canViewContent ? .otherProfile : .privateProfile
    }

    var title: String {
        switch self {
        case .ownProfile:
            return "Share your first Spot"
        case .otherProfile:
            return "No Spots yet"
        case .privateProfile:
            return "This account is private"
        }
    }

    var message: String {
        switch self {
        case .ownProfile:
            return "Start your collection by sharing a place you love."
        case .otherProfile:
            return "They haven't shared any Spots yet."
        case .privateProfile:
            return "Follow this user to see the Spots they share."
        }
    }

    var showsPostButton: Bool {
        self == .ownProfile
    }
}

struct ProfileView: View {
    var userId: String?
    var fromNavigationPush: Bool = false
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedTab = "Spots"
    @State private var selectedSpot: Spot?
    @State private var showMenu: Bool = false
    @State private var showSettingsNav: Bool = false
    @State private var showLikesNav: Bool = false
    @State private var showBookmarksNav: Bool = false
    @State private var showFollowRequestsNav: Bool = false
    @State private var showAlgorithmNav: Bool = false
    @State private var isMapExpanded: Bool = false
    @State private var showOtherUserMenu: Bool = false
    @State private var showProfileReportSheet: Bool = false
    @State private var showBlockConfirm: Bool = false
    @State private var blockInFlight: Bool = false
    @State private var blockErrorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private let tabs = ["Spots", "Map"]

    @MainActor
    init(
        userId: String?,
        fromNavigationPush: Bool = false
    ) {
        self.userId = userId
        self.fromNavigationPush = fromNavigationPush
        _viewModel = StateObject(wrappedValue: ProfileViewModel())
    }

    @MainActor
    init(
        userId: String?,
        fromNavigationPush: Bool = false,
        viewModel: ProfileViewModel
    ) {
        self.userId = userId
        self.fromNavigationPush = fromNavigationPush
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isOwnProfile: Bool {
        userId == nil || userId == authVM.userId
    }

    var body: some View {
        let content = profileContent
        
        if fromNavigationPush {
            // Already in parent NavigationStack, don't wrap
            content
        } else {
            // Root view, wrap in NavigationStack
            NavigationStack {
                content
            }
        }
    }
    
    private var profileContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // MARK: — Top Bar (left-aligned title)
                HStack(spacing: 0) {
                    let isViewingOther = (userId != nil) && (userId != authVM.userId)
                    
                    // Always show back button when viewing other user's profile or when navigated from another screen
                    if fromNavigationPush || isViewingOther {
                        Button {
                            if selectedSpot != nil {
                                // If spot is selected, go back to profile first
                                withAnimation { self.selectedSpot = nil }
                            } else {
                                // Otherwise, dismiss the entire profile view
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 8)
                    } else if selectedSpot != nil {
                        // Show back button when spot is expanded (own profile)
                        Button {
                            withAnimation { self.selectedSpot = nil }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Constants.Colors.primary)
                                Text("Back to profile")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(Constants.Colors.primary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if selectedSpot == nil {
                        Text("Spot")
                            .font(FontManager.logoTitle())
                            .foregroundColor(Constants.Colors.primary)
                    }

                    Spacer()

                    if selectedSpot == nil && (userId == nil || userId == authVM.userId) {
                        Button {
                            withAnimation { showMenu.toggle() }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Menu")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(Constants.Colors.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Constants.Colors.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Constants.Colors.primary, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("profile.menuButton")
                    } else if selectedSpot == nil,
                              let viewedUserId = userId,
                              viewedUserId != authVM.userId {
                        // Report / Block menu for other users (Apple Guideline 1.2 entry point).
                        Button {
                            withAnimation { showOtherUserMenu.toggle() }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Constants.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Constants.Colors.primary, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("profile.otherUserMenuButton")
                    }
                }
                .padding(.horizontal, 16)
                .safeAreaPadding(.top)
                .padding(.top, 8)

                // MARK: — Loading State
                if viewModel.isLoading {
                    ProfileLoadingPlaceholder()
                } else {
                    // MARK: — Profile Header + Tabs
                    VStack(spacing: 16) {
                        // Collapsed header when spot is selected on map, full header otherwise
                        if selectedSpot == nil && !(selectedTab == "Map" && isMapExpanded) {
                            // Full header
                            VStack(spacing: 12) {
                                if let urlString = viewModel.profileImageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                                    RemoteImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                        case .failure(let failure):
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                                .onAppear {
                                                    SpotLogger.log(ProfileViewLogs.profileImageLoadFailed, details: [
                                                        "url": urlString,
                                                        "statusCode": failure.statusCode as Any,
                                                        "error": failure.underlying.localizedDescription
                                                    ])
                                                }
                                        case .empty:
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                        @unknown default:
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                }

                                HStack(spacing: 8) {
                                    Text(viewModel.username ?? "")
                                        .font(FontManager.sectionHeader())
                                        .foregroundColor(.black)
                                    if (userId == nil || userId == authVM.userId) ? authVM.isPro : viewModel.isProProfile {
                                        Text("Pro")
                                            .font(.caption)
                                            .foregroundColor(Constants.Colors.buttonText)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Constants.Colors.primary)
                                            .cornerRadius(10)
                                    }
                                }

                                Text("\(viewModel.spots.count) spots shared")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 12)
                        } else if selectedSpot != nil && selectedTab == "Map" {
                            // Collapsed header when spot is selected on map
                            HStack(spacing: 12) {
                                if let urlString = viewModel.profileImageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                                    RemoteImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                        case .failure(let failure):
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                                .onAppear {
                                                    SpotLogger.log(ProfileViewLogs.profileImageLoadFailed, details: [
                                                        "url": urlString,
                                                        "statusCode": failure.statusCode as Any,
                                                        "error": failure.underlying.localizedDescription
                                                    ])
                                                }
                                        case .empty:
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                        @unknown default:
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(viewModel.username ?? "")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(.black)
                                
                                if (userId == nil || userId == authVM.userId) ? authVM.isPro : viewModel.isProProfile {
                                    Text("Pro")
                                        .font(.caption2)
                                        .foregroundColor(Constants.Colors.buttonText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Constants.Colors.primary)
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Follow / Request actions centered under header when viewing someone else
                        if selectedSpot == nil,
                           let viewedUserId = userId,
                           viewedUserId != authVM.userId {
                            VStack {
                                if viewModel.isFollowingUser {
                                    Button {
                                        viewModel.unfollow(targetUserId: viewedUserId)
                                    } label: {
                                        Text("Unfollow")
                                            .font(FontManager.primaryText())
                                            .foregroundColor(Constants.Colors.buttonText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Constants.Colors.primary)
                                            .cornerRadius(20)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityIdentifier("profile.unfollowButton")
                                } else if viewModel.isPrivateProfile {
                                    VStack(spacing: 8) {
                                        Button {
                                            if viewModel.hasRequestedFollow { return }
                                            viewModel.requestFollow(targetUserId: viewedUserId)
                                        } label: {
                                            Text(viewModel.hasRequestedFollow ? "Requested" : "Request to Follow")
                                                .font(FontManager.primaryText())
                                                .foregroundColor(Constants.Colors.buttonText)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Constants.Colors.primary)
                                                .cornerRadius(20)
                                        }
                                        .disabled(viewModel.hasRequestedFollow)
                                        .buttonStyle(PlainButtonStyle())

                                        if viewModel.hasRequestedFollow {
                                            Button {
                                                viewModel.cancelFollowRequest(targetUserId: viewedUserId)
                                            } label: {
                                                Text("Cancel Request")
                                                    .font(FontManager.primaryText())
                                                    .foregroundColor(Constants.Colors.primary)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                } else {
                                    Button {
                                        viewModel.follow(targetUserId: viewedUserId)
                                    } label: {
                                        Text("Follow")
                                            .font(FontManager.primaryText())
                                            .foregroundColor(Constants.Colors.buttonText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Constants.Colors.primary)
                                            .cornerRadius(20)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityIdentifier("profile.followButton")
                                }
                            }
                            .padding(.bottom, 8)
                        }

                        if selectedSpot == nil {
                            HStack(spacing: 24) {
                                ForEach(tabs, id: \.self) { tab in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTab = tab
                                        }
                                    } label: {
                                        Text(tab)
                                            .font(FontManager.primaryText())
                                            .foregroundColor(selectedTab == tab ? Constants.Colors.primary : .gray)
                                            .fontWeight(.semibold)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("profile.\(tab.lowercased())Tab")
                                }
                            }
                        }

                        if selectedTab == "Spots" {
                            if let selectedSpot {
                                SpotCard(
                                    spot: selectedSpot,
                                    showUserInfo: false,
                                    userId: userId,
                                    onDelete: { deleteSpot(selectedSpot) },
                                    source: "ProfileInline"
                                    // backAction removed - now handled by ProfileView top bar
                                )
                                .transition(.opacity)
                                .zIndex(1)
                            } else {
                                Group {
                                    if viewModel.spots.isEmpty {
                                        profileSpotsEmptyState
                                    } else {
                                        SpotsGridView(spots: viewModel.spots) { tapped in
                                            selectedSpot = tapped
                                        }
                                    }
                                }
                                .zIndex(0)
                            }
                        } else {
                            // Map tab
                            ProfileMapView(spots: viewModel.spots, onSpotTap: { tapped in
                                selectedSpot = tapped
                            }, onDeleteSpot: { spot in
                                deleteSpot(spot)
                            }, onCollapseChange: { expanded in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { isMapExpanded = expanded }
                            })
                            .zIndex(0)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Custom dropdown overlay
            if showMenu {
                // Tappable background to dismiss
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showMenu = false } }

                VStack(alignment: .leading, spacing: 0) {
                    if userId == nil || userId == authVM.userId, !viewModel.isProProfile {
                        Button {
                            withAnimation { showMenu = false }
                            SpotLogger.log(ProfileViewLogs.openPaywallFromProfileMenu)
                            NotificationCenter.default.post(name: .showPaywall, object: nil)
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Go Pro")
                                    .font(FontManager.primaryText())
                            }
                            .foregroundColor(Constants.Colors.primary)
                            .padding(12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                    }
                    Button {
                        withAnimation { showMenu = false }
                        showLikesNav = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("Your Likes")
                                .font(FontManager.primaryText())
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()

                    Button {
                        withAnimation { showMenu = false }
                        showBookmarksNav = true
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            Text("Your Bookmarks")
                                .font(FontManager.primaryText())
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()

                    if viewModel.isPrivateProfile {
                        Button {
                            withAnimation { showMenu = false }
                            showFollowRequestsNav = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Follow Requests")
                                    .font(FontManager.primaryText())
                                if viewModel.followRequestsCount > 0 {
                                    Text("\(viewModel.followRequestsCount)")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Constants.Colors.primary)
                                        .foregroundColor(Constants.Colors.buttonText)
                                        .cornerRadius(8)
                                }
                            }
                            .foregroundColor(Constants.Colors.primary)
                            .padding(12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                    }

                    if userId == nil || userId == authVM.userId {
                        Button {
                            withAnimation { showMenu = false }
                            showAlgorithmNav = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Your Algorithm")
                                    .font(FontManager.primaryText())
                            }
                            .foregroundColor(Constants.Colors.primary)
                            .padding(12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                    }

                    Button {
                        withAnimation { showMenu = false }
                        showSettingsNav = true
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                                .font(FontManager.primaryText())
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("profile.settingsEntry")
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Constants.Colors.primary, lineWidth: 1)
                )
                .frame(width: UIScreen.main.bounds.width * 0.5)
                .padding(.trailing, 16)
                .padding(.top, 44)
            }

            // Custom Report/Block menu when viewing another user's profile.
            if showOtherUserMenu, let viewedUserId = userId, viewedUserId != authVM.userId {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showOtherUserMenu = false } }

                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation { showOtherUserMenu = false }
                        showProfileReportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "flag")
                            Text("Report User")
                                .font(FontManager.primaryText())
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("profile.reportUserAction")

                    Divider()

                    Button {
                        withAnimation { showOtherUserMenu = false }
                        showBlockConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "circle.slash")
                            Text("Block User")
                                .font(FontManager.primaryText())
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("profile.blockUserAction")
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Constants.Colors.primary, lineWidth: 1)
                )
                .frame(width: UIScreen.main.bounds.width * 0.55)
                .padding(.trailing, 16)
                .padding(.top, 44)
            }
        }
        .background(Constants.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showProfileReportSheet) {
            if let viewedUserId = userId,
               let uuid = UUID(uuidString: viewedUserId) {
                ProfileReportSheet(
                    reportedUserId: uuid,
                    reportedUsername: viewModel.username
                )
                .environmentObject(authVM)
            }
        }
        .alert("Block this user?", isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Block User", role: .destructive) {
                Task { await performBlockUser() }
            }
        } message: {
            Text("You won't see their spots or profile content in your feed. This also notifies Spot's moderation systems for safety review.")
        }
        .alert("Couldn't block user", isPresented: Binding(
            get: { blockErrorMessage != nil },
            set: { if !$0 { blockErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { blockErrorMessage = nil }
        } message: {
            Text(blockErrorMessage ?? "")
        }
        .accessibilityIdentifier("profile.screenRoot")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let viewingOther = (userId != nil) && (userId != authVM.userId)
            Task { await viewModel.loadUser(userId: userId, forceReload: viewingOther) }
            let isSelf = (userId == nil) || (userId == authVM.userId)
            if isSelf && viewModel.isPrivateProfile {
                viewModel.startFollowRequestsListener(ownUserId: authVM.userId)
            }
        }
        .onChange(of: showSettingsNav) { _, isShowing in
            if !isShowing {
                Task { await viewModel.loadUser(userId: userId, forceReload: true) }
            }
        }
        .onDisappear {
            viewModel.stopFollowRequestsListener()
            Task { @MainActor in
                selectedSpot = nil
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        .navigationDestination(isPresented: $showSettingsNav) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showLikesNav) {
            SpotGridScreen(context: .likes, userId: userId)
        }
        .navigationDestination(isPresented: $showBookmarksNav) {
            if authVM.isPro {
                BookmarksCollectionsScreen()
                    .environmentObject(authVM)
            } else {
                SpotGridScreen(context: .bookmarks, userId: userId)
            }
        }
        .navigationDestination(isPresented: $showFollowRequestsNav) {
            FollowRequestsView()
        }
        .navigationDestination(isPresented: $showAlgorithmNav) {
            FeedProfileView()
                .environmentObject(authVM)
        }
        .onChange(of: viewModel.spots) { _, spots in
            guard let selectedSpot else { return }
            if !spots.contains(where: { $0.id == selectedSpot.id }) {
                self.selectedSpot = nil
                isMapExpanded = false
            }
        }
        .onChange(of: authVM.isPro) { _, newValue in
            if userId == nil || userId == authVM.userId {
                viewModel.isProProfile = newValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
            guard !fromNavigationPush else { return }
            guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 4 else { return }
            resetProfileTabToRoot()
        }
    }

    private func deleteSpot(_ spot: Spot) {
        Task {
            await viewModel.deleteSpot(spot)
            selectedSpot = nil
            isMapExpanded = false
        }
    }

    private var profileSpotsEmptyState: some View {
        let state = ProfileSpotsEmptyState.resolve(
            isOwnProfile: isOwnProfile,
            canViewContent: viewModel.canViewContent
        )

        return VStack(spacing: 16) {
            Image(systemName: state == .privateProfile ? "lock.fill" : "mappin.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Constants.Colors.primary.opacity(0.55))

            Text(state.title)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)

            Text(state.message)
                .font(FontManager.primaryText())
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            if state.showsPostButton {
                Button {
                    NotificationCenter.default.post(
                        name: .selectMainTab,
                        object: nil,
                        userInfo: [
                            SpotMainTabNotification.userInfoTabIndexKey:
                                SpotMainTabNotification.postTabIndex
                        ]
                    )
                } label: {
                    Text("Post a Spot")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Constants.Colors.primary)
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("profile.postFirstSpotButton")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.spotsEmptyState")
    }

    /// Root Profile tab re-tap: return to the main profile surface (not used when embedded from Home/Map/Search).
    private func resetProfileTabToRoot() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSpot = nil
            selectedTab = "Spots"
            showMenu = false
            showOtherUserMenu = false
            showSettingsNav = false
            showLikesNav = false
            showBookmarksNav = false
            showFollowRequestsNav = false
            showAlgorithmNav = false
            isMapExpanded = false
        }
    }

    /// Performs the block action for the currently viewed profile and dismisses
    /// back to the previous screen. Optimistically removes the blocked user's
    /// content from the home feed.
    @MainActor
    private func performBlockUser() async {
        guard let viewedUserId = userId,
              viewedUserId != authVM.userId,
              !blockInFlight else { return }
        blockInFlight = true
        defer { blockInFlight = false }
        do {
            try await authVM.blockUser(userId: viewedUserId)
            NotificationCenter.default.post(
                name: .homeFeedLocallyRemove,
                object: nil,
                userInfo: [SpotHomeFeedNotification.authorUserIdKey: viewedUserId]
            )
            SpotLogger.log(ModerationServiceLogs.userBlocked, details: [
                "blockedUserId": viewedUserId,
                "source": "profile_view_menu"
            ])
            dismiss()
        } catch {
            blockErrorMessage = "Check your connection and try again."
            SpotLogger.log(ModerationServiceLogs.userBlockFailed, details: [
                "blockedUserId": viewedUserId,
                "error": error.localizedDescription
            ])
        }
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.isPro = true
    return ProfileView(userId: nil, fromNavigationPush: false)
        .environmentObject(auth)
}
