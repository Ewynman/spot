//
//  HomepageView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct HomepageView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var feedVM = FeedViewModel()
    @State private var homeNavigationPath = NavigationPath()
    @State private var showVerifyToast = false
    @State private var showPostSuccessToast = false
    @State private var postSuccessToastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $homeNavigationPath) {
            VStack(spacing: 0) {
                // Top bar: SPOT branding only (no plus; Post is its own tab)
                TopNavigationView(
                    title: "SPOT",
                    rightButton: .none,
                    showUploadView: .constant(false)
                )

                // Feed content only
                FeedContentView(
                    isLoading: $feedVM.isLoading,
                    isLoadingMore: feedVM.loadState == .loadingMore,
                    spots: feedVM.spots,
                    mapSpots: feedVM.mapSpots,
                    selectedTab: "Feed",
                    onScrolledToBottom: { feedVM.loadMoreSpots() },
                    onRefresh: { await feedVM.refreshFeed() },
                    userId: authVM.userId,
                    onDeleteSpot: { spot in
                        Task { await feedVM.delete(spot: spot) }
                    },
                    onFirstItemAppeared: { feedVM.recordFirstItemIfNeeded() },
                    refreshErrorMessage: feedVM.refreshErrorMessage,
                    emptyStatus: feedVM.emptyStatus?.status,
                    onCellAppear: { spot in
                        FeedEventService.recordImpression(spot: spot)
                    },
                    onCellDisappear: { spot in
                        FeedEventService.recordCellLeftViewport(spot: spot)
                    },
                    onEnsureSpotVisible: { spot in
                        feedVM.insertNewSpot(spot)
                    }
                )
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if showVerifyToast {
                        ToastView(message: "Please verify your email to post a spot.", isError: true)
                            .transition(.move(edge: .top))
                    }
                    if showPostSuccessToast {
                        SuccessToastView(message: "Spot posted!")
                            .transition(.move(edge: .top))
                    }
                }
                .padding(.top, 8)
            }
            .background(Color(hex: "F5F3EF"))
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .profile(let userId):
                    ProfileView(userId: userId, fromNavigationPush: true)
                        .navigationBarBackButtonHidden(true)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityIdentifier("home.feedRoot")
            .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
                guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 0 else { return }
                homeNavigationPath = NavigationPath()
            }
        }
        .onAppear {
            Task {
                await feedVM.loadInitialSpots()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeFeedLocallyRemove)) { output in
            let info = output.userInfo ?? [:]
            Task { @MainActor in
                if let authorId = info[SpotHomeFeedNotification.authorUserIdKey] as? String, !authorId.isEmpty {
                    feedVM.locallyRemoveSpotsFromAuthor(userId: authorId)
                } else if let spotId = info[SpotHomeFeedNotification.spotIdKey] as? String, !spotId.isEmpty {
                    feedVM.locallyRemoveSpot(id: spotId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spotDidUpdate)) { output in
            guard let updatedSpot = output.object as? Spot else { return }
            feedVM.locallyReplaceSpot(updatedSpot)
        }
        .onReceive(NotificationCenter.default.publisher(for: .spotDidPostSuccess)) { notification in
            postSuccessToastTask?.cancel()
            showPostSuccessToast = true
            if let postedSpot = notification.userInfo?["postedSpot"] as? Spot {
                feedVM.insertNewSpot(postedSpot)
            }
            postSuccessToastTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    withAnimation {
                        showPostSuccessToast = false
                    }
                }
            }
        }
        .onDisappear {
            postSuccessToastTask?.cancel()
        }
    }
}

#Preview() {
    HomepageView()
        .environmentObject(AuthViewModel())
}

// Place-first Home card preview
#Preview {
    HomeSpotCard(spot: Spot(
        id: "test123",
        userId: "user123",
        username: "TestUser",
        userProfileImageURL: nil,
        imageURL: "https://via.placeholder.com/300",
        vibeTag: "Chill Spot",
        latitude: 37.78,
        longitude: -122.4,
        locationName: "Test Location",
        likes: 5,
        isLiked: false,
        isSaved: false,
        createdAt: Date()
    ), userId: "user123")
    .environmentObject(AuthViewModel())
}
