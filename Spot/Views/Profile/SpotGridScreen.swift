//
//  SpotGridScreen.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import SwiftUI

enum SpotGridContext {
    case likes
    case bookmarks

    var title: String {
        switch self {
        case .likes:
            return "Your Likes"
        case .bookmarks:
            return "Your Bookmarks"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .likes:
            return "No Liked Spots"
        case .bookmarks:
            return "No Saved Spots"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .likes:
            return "You haven't liked any spots yet."
        case .bookmarks:
            return "You haven't saved any spots yet."
        }
    }

    var emptyStateIcon: String {
        switch self {
        case .likes:
            return "heart"
        case .bookmarks:
            return "bookmark"
        }
    }
}

#Preview {
    let auth = AuthViewModel()
    let sampleSpots = [
        Spot(id: "1", userId: "u1", username: "eddie", imageURL: "https://picsum.photos/seed/g1/800/600", vibeTag: "View", latitude: 37.0, longitude: -122.0, locationName: "SF", createdAt: Date()),
        Spot(id: "2", userId: "u1", username: "eddie", imageURL: "https://picsum.photos/seed/g2/800/600", vibeTag: "Cafe", latitude: 34.0, longitude: -118.0, locationName: "LA", createdAt: Date())
    ]
    let vm = BookmarksViewModel()
    vm.spots = sampleSpots
    return SpotGridScreen(context: .bookmarks, userId: "u1")
        .environmentObject(auth)
}

struct SpotGridScreen: View {
    let context: SpotGridContext
    let userId: String?

    @StateObject private var likesViewModel = LikesViewModel()
    @StateObject private var bookmarksViewModel = BookmarksViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpot: Spot?

    private var viewModel: (any ObservableObject) {
        switch context {
        case .likes:
            return likesViewModel
        case .bookmarks:
            return bookmarksViewModel
        }
    }

    private var spots: [Spot] {
        switch context {
        case .likes:
            return likesViewModel.spots
        case .bookmarks:
            return bookmarksViewModel.spots
        }
    }

    private var isLoading: Bool {
        switch context {
        case .likes:
            return likesViewModel.isLoading
        case .bookmarks:
            return bookmarksViewModel.isLoading
        }
    }

    private var errorMessage: String? {
        switch context {
        case .likes:
            return likesViewModel.errorMessage
        case .bookmarks:
            return bookmarksViewModel.errorMessage
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button {
                    if selectedSpot != nil {
                        SpotLogger.log(SpotGridScreenLogs.headerBackClearsInlineSpot, details: ["context": String(describing: context)])
                        withAnimation { selectedSpot = nil }
                    } else {
                        SpotLogger.log(SpotGridScreenLogs.backButtonTapped, details: ["context": String(describing: context)])
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text(context.title)
                    .font(FontManager.sectionHeader())
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primary)

                Spacer()

                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .buttonStyle(PlainButtonStyle())

            // Content
            if isLoading && spots.isEmpty {
                SpotGridLoadingPlaceholder(columns: 3, cellCount: 9)
            } else if let errorMessage = errorMessage {
                // Error state
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Something went wrong")
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)

                    Text(errorMessage)
                        .font(FontManager.primaryText())
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button {
                        Task {
                            await loadData()
                        }
                    } label: {
                        Text("Retry")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Constants.Colors.primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                }
            } else if spots.isEmpty {
                // Empty state
                emptyStateView
            } else {
                if let selectedSpot {
                    // Show expanded spot - header stays visible
                    ScrollView {
                        SpotCard(
                            spot: selectedSpot,
                            showUserInfo: false,
                            userId: userId,
                            onDelete: nil,
                            source: "\(context)",
                            backAction: nil, // Don't show back button, header handles it
                            mediaPresentation: .detail
                        )
                        .padding(.top, 8)
                    }
                    .transition(.opacity)
                } else {
                    // Grid content
                    SpotsGridView(
                        spots: spots,
                        onSpotTapped: { spot in
                            SpotLogger.log(SpotGridScreenLogs.openSpotFromGrid, details: [
                                "context": String(describing: context),
                                "spotId": spot.safeId
                            ])
                            withAnimation {
                                selectedSpot = spot
                            }
                        },
                        columns: 3
                    )
                    .refreshable {
                        await loadData()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F5F3EF"))
        .navigationBarBackButtonHidden(true)
        .onChange(of: authVM.bookmarkedSpots) { _, bookmarkedSpotIds in
            guard case .bookmarks = context else { return }
            let savedIds = Set(bookmarkedSpotIds)
            bookmarksViewModel.spots.removeAll { !savedIds.contains($0.safeId) }
            if let selectedSpot, !savedIds.contains(selectedSpot.safeId) {
                self.selectedSpot = nil
            }
        }
        .onAppear {
            SpotLogger.log(SpotGridScreenLogs.onAppear, details: ["context": String(describing: context)])

            Task {
                await loadData()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: context.emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(context.emptyStateTitle)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)

            Text(context.emptyStateMessage)
                .font(FontManager.primaryText())
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Explore the feed")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadData() async {
        SpotLogger.log(SpotGridScreenLogs.loadData, details: ["context": String(describing: context)])

        do {
            switch context {
            case .likes:
                await likesViewModel.loadInitial()
            case .bookmarks:
                await bookmarksViewModel.loadInitial()
            }
            SpotLogger.log(SpotGridScreenLogs.dataLoaded, details: ["context": String(describing: context)])
        }
    }
}
