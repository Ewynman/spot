//
//  SpotPreviewCard.swift
//  Spot
//
//  Compact floating map preview (~120–140 pt). Thumbnail, author, location,
//  and Like/Save are always visible without scrolling.
//

import SwiftUI
import UIKit

struct SpotPreviewCard: View {
    let spot: Spot
    var surface: MapAnalyticsSurface = .global
    var onOpenDetail: () -> Void
    var onLikeChanged: ((Bool) -> Void)? = nil
    var onSaveChanged: ((Bool) -> Void)? = nil

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isLiked = false
    @State private var isSaved = false
    @State private var isLoadingLike = false
    @State private var isLoadingSave = false
    @State private var showShareSheet = false

    private var cardHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return Constants.MapDesign.compactPreviewHeight + 28
        }
        return Constants.MapDesign.compactPreviewHeight
    }

    private var authorDisplay: SpotAuthorDisplay {
        SpotAuthorDisplay.resolve(
            spotUsername: spot.username,
            spotProfileImageURL: spot.userProfileImageURL,
            isCurrentUser: spot.userId == authVM.userId,
            currentUsername: authVM.currentUserUsername,
            currentProfileImageURL: authVM.currentUserProfileImageURL
        )
    }

    private var metadataLine: String? {
        let vibes = spot.visibleVibeLabelsForCard()
        if let first = vibes.first { return first }
        return nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail
                .frame(
                    width: Constants.MapDesign.compactPreviewThumbnail,
                    height: Constants.MapDesign.compactPreviewThumbnail
                )

            VStack(alignment: .leading, spacing: 4) {
                authorRow
                Text(spot.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                     ?? "Unknown location")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.textPrimary.opacity(0.75))
                    .lineLimit(1)
                if let meta = metadataLine {
                    Text(meta)
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.textPrimary.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                actionRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .background(Constants.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: Constants.MapDesign.compactPreviewCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: Constants.MapDesign.compactPreviewCornerRadius, style: .continuous))
        .onTapGesture { onOpenDetail() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height < -40 {
                        onOpenDetail()
                    }
                }
        )
        .onAppear { syncFlags() }
        .onChange(of: spot.safeId) { _, _ in syncFlags() }
        .onChange(of: authVM.likedSpots) { _, _ in
            isLiked = authVM.likedSpots.contains(spot.safeId)
        }
        .onChange(of: authVM.bookmarkedSpots) { _, _ in
            isSaved = authVM.bookmarkedSpots.contains(spot.safeId)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(spot: spot)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.spotPreview")
        .accessibilityHint("Double-tap to open spot detail")
    }

    private var thumbnail: some View {
        Group {
            if let urlString = (spot.thumbnailURL ?? spot.imageURL)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                RemoteImage(url: url, maxPixelSize: 400) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        placeholderThumb
                    @unknown default:
                        placeholderThumb
                    }
                }
            } else {
                placeholderThumb
            }
        }
        .frame(
            width: Constants.MapDesign.compactPreviewThumbnail,
            height: Constants.MapDesign.compactPreviewThumbnail
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholderThumb: some View {
        ZStack {
            Constants.Colors.accent
            Image(systemName: "photo")
                .foregroundColor(Constants.Colors.primary.opacity(0.45))
        }
    }

    private var authorRow: some View {
        HStack(spacing: 6) {
            avatar
            Text(authorDisplay.username)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.textPrimary)
                .lineLimit(1)
        }
    }

    private var avatar: some View {
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
                    .overlay(
                        Text(String(authorDisplay.username.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                    )
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
    }

    private var actionRow: some View {
        HStack(spacing: 4) {
            Button {
                toggleLike()
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isLiked ? .red : Constants.Colors.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoadingLike || authVM.userId == nil)
            .accessibilityLabel(isLiked ? "Unlike spot" : "Like spot")
            .accessibilityAddTraits(isLiked ? [.isSelected] : [])

            Button {
                toggleSave()
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSaved ? Constants.Colors.primary : Constants.Colors.primary.opacity(0.55))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoadingSave || authVM.userId == nil)
            .accessibilityLabel(isSaved ? "Remove from saved" : "Save spot")
            .accessibilityAddTraits(isSaved ? [.isSelected] : [])
            .accessibilityIdentifier("map.preview.save")

            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share spot")

            Spacer(minLength: 0)
        }
    }

    private func syncFlags() {
        isLiked = authVM.likedSpots.contains(spot.safeId) || (spot.isLiked == true)
        isSaved = authVM.bookmarkedSpots.contains(spot.safeId) || (spot.isSaved == true)
    }

    private func toggleLike() {
        guard !isLoadingLike, let spotId = spot.id, authVM.userId != nil else { return }
        isLoadingLike = true
        isLiked.toggle()
        if isLiked {
            authVM.likeSpot(spotId)
        } else {
            authVM.unlikeSpot(spotId)
        }
        isLoadingLike = false
        onLikeChanged?(isLiked)
        MapAnalytics.previewLiked(surface: surface, spotId: spotId, isLiked: isLiked)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func toggleSave() {
        guard !isLoadingSave, let spotId = spot.id, authVM.userId != nil else { return }
        let previous = isSaved
        let target = !isSaved
        isSaved = target
        isLoadingSave = true
        if target {
            if !authVM.bookmarkedSpots.contains(spotId) {
                authVM.bookmarkedSpots.append(spotId)
            }
        } else {
            authVM.bookmarkedSpots.removeAll { $0 == spotId }
        }
        Task { @MainActor in
            do {
                try await UserSpotService.shared.setBookmark(spotId: spotId, isSaved: target)
                isLoadingSave = false
                onSaveChanged?(target)
                MapAnalytics.previewSaved(surface: surface, spotId: spotId, isSaved: target)
            } catch {
                isSaved = previous
                if previous {
                    if !authVM.bookmarkedSpots.contains(spotId) {
                        authVM.bookmarkedSpots.append(spotId)
                    }
                } else {
                    authVM.bookmarkedSpots.removeAll { $0 == spotId }
                }
                isLoadingSave = false
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#Preview("Spot preview card") {
    SpotPreviewCard(
        spot: Spot(
            id: "1",
            userId: "u1",
            username: "Eddie5",
            imageURL: "https://picsum.photos/seed/map/400",
            vibeTag: "Hidden Gem",
            locationName: "Middle of Nowhere"
        ),
        onOpenDetail: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
    .environmentObject(AuthViewModel())
}
