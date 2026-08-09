//
//  SpotDetailSheet.swift
//  Spot
//
//  Expanded map spot detail presented as a secondary sheet with a persistent
//  Like / Save / Share action bar that never scrolls away.
//

import SwiftUI
import UIKit

struct SpotDetailSheet: View {
    let spot: Spot
    var surface: MapAnalyticsSurface = .global
    var allowDelete: Bool = false
    var onDelete: (() -> Void)? = nil
    var onDismiss: () -> Void

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isLiked = false
    @State private var isSaved = false
    @State private var isLoadingLike = false
    @State private var isLoadingSave = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false

    private var authorDisplay: SpotAuthorDisplay {
        SpotAuthorDisplay.resolve(
            spotUsername: spot.username,
            spotProfileImageURL: spot.userProfileImageURL,
            isCurrentUser: spot.userId == authVM.userId,
            currentUsername: authVM.currentUserUsername,
            currentProfileImageURL: authVM.currentUserProfileImageURL
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    heroImage
                    creatorBlock
                    if let location = spot.locationName?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.textPrimary)
                    }
                    let vibes = spot.visibleVibeLabelsForCard()
                    if !vibes.isEmpty {
                        FlowVibeTags(tags: vibes)
                    }
                    if let created = spot.createdAt {
                        Text(created.formatted(date: .abbreviated, time: .shortened))
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.textPrimary.opacity(0.55))
                    }
                    if allowDelete {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Spot")
                                .font(FontManager.buttonText())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, Constants.Layout.Spacing.large)
                .padding(.top, Constants.Layout.Spacing.medium)
                .padding(.bottom, 24)
            }

            Divider()
            persistentActionBar
                .padding(.horizontal, Constants.Layout.Spacing.large)
                .padding(.vertical, 10)
                .background(Constants.Colors.background)
        }
        .background(Constants.Colors.background.ignoresSafeArea())
        .onAppear { syncFlags() }
        .onChange(of: authVM.likedSpots) { _, _ in
            isLiked = authVM.likedSpots.contains(spot.safeId)
        }
        .onChange(of: authVM.bookmarkedSpots) { _, _ in
            isSaved = authVM.bookmarkedSpots.contains(spot.safeId)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(spot: spot)
        }
        .confirmationDialog("Delete this Spot?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityIdentifier("map.spotDetail")
    }

    private var heroImage: some View {
        Group {
            if let urlString = (spot.imageURL ?? spot.thumbnailURL)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                RemoteImage(url: url, maxPixelSize: 1200) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        heroPlaceholder
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var heroPlaceholder: some View {
        ZStack {
            Constants.Colors.accent
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundColor(Constants.Colors.primary.opacity(0.4))
        }
    }

    private var creatorBlock: some View {
        HStack(spacing: 10) {
            Group {
                if let urlString = authorDisplay.profileImageURL,
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle().fill(Constants.Colors.accent)
                        }
                    }
                } else {
                    Circle().fill(Constants.Colors.accent)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            Text(authorDisplay.username)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
        }
    }

    private var persistentActionBar: some View {
        HStack(spacing: 8) {
            actionButton(
                systemName: isLiked ? "heart.fill" : "heart",
                color: isLiked ? .red : Constants.Colors.primary,
                label: isLiked ? "Unlike spot" : "Like spot",
                selected: isLiked
            ) {
                toggleLike()
            }
            .disabled(isLoadingLike || authVM.userId == nil)

            actionButton(
                systemName: isSaved ? "bookmark.fill" : "bookmark",
                color: Constants.Colors.primary,
                label: isSaved ? "Remove from saved" : "Save spot",
                selected: isSaved
            ) {
                toggleSave()
            }
            .disabled(isLoadingSave || authVM.userId == nil)
            .accessibilityIdentifier("map.detail.save")

            actionButton(
                systemName: "square.and.arrow.up",
                color: Constants.Colors.primary,
                label: "Share spot",
                selected: false
            ) {
                showShareSheet = true
            }

            Spacer()
        }
    }

    private func actionButton(
        systemName: String,
        color: Color,
        label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func syncFlags() {
        isLiked = authVM.likedSpots.contains(spot.safeId) || (spot.isLiked == true)
        isSaved = authVM.bookmarkedSpots.contains(spot.safeId) || (spot.isSaved == true)
    }

    private func toggleLike() {
        guard !isLoadingLike, let spotId = spot.id, authVM.userId != nil else { return }
        isLiked.toggle()
        if isLiked {
            authVM.likeSpot(spotId)
        } else {
            authVM.unlikeSpot(spotId)
        }
        MapAnalytics.previewLiked(surface: surface, spotId: spotId, isLiked: isLiked)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleSave() {
        guard !isLoadingSave, let spotId = spot.id, authVM.userId != nil else { return }
        let previous = isSaved
        let target = !isSaved
        isSaved = target
        isLoadingSave = true
        if target {
            if !authVM.bookmarkedSpots.contains(spotId) { authVM.bookmarkedSpots.append(spotId) }
        } else {
            authVM.bookmarkedSpots.removeAll { $0 == spotId }
        }
        Task { @MainActor in
            do {
                try await UserSpotService.shared.setBookmark(spotId: spotId, isSaved: target)
                isLoadingSave = false
                MapAnalytics.previewSaved(surface: surface, spotId: spotId, isSaved: target)
            } catch {
                isSaved = previous
                if previous {
                    if !authVM.bookmarkedSpots.contains(spotId) { authVM.bookmarkedSpots.append(spotId) }
                } else {
                    authVM.bookmarkedSpots.removeAll { $0 == spotId }
                }
                isLoadingSave = false
            }
        }
    }
}

/// Simple wrap of vibe chips for the detail sheet.
private struct FlowVibeTags: View {
    let tags: [String]
    var body: some View {
        FlexibleVibeWrap(tags: tags)
    }
}

private struct FlexibleVibeWrap: View {
    let tags: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Constants.Colors.accent)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    SpotDetailSheet(
        spot: Spot(
            id: "1",
            username: "Eddie5",
            imageURL: "https://picsum.photos/seed/d/800",
            vibeTag: "Cafe",
            locationName: "Brooklyn",
            createdAt: Date()
        ),
        onDismiss: {}
    )
    .environmentObject(AuthViewModel())
}
