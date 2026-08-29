//
//  MapSpotPreviewCard.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct MapSpotPreviewCard: View {
    let spot: Spot
    var allowDelete: Bool = false
    var source: String
    var onBackToAll: (() -> Void)?
    var onClose: () -> Void
    var onDelete: (() -> Void)?
    /// When non-`nil`, shows top grabber + maps swipe-from-handle to peek/expanded.
    var drawerDetent: Binding<MapSpotDrawerDetent>? = nil

    private var showsExpansionChrome: Bool { drawerDetent != nil }
    /// Profile map: back + close. Discovery drawer: omit empty header row (dismiss via swipe).
    private var showsProfileChromeHeader: Bool {
        !showsExpansionChrome || onBackToAll != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            drawerTopSection
            ScrollView(showsIndicators: false) {
                SpotCard(
                    spot: spot,
                    showUserInfo: true,
                    userId: nil,
                    onDelete: { onDelete?() },
                    source: source,
                    mediaPresentation: .mapDrawer
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Constants.Layout.Spacing.large)
                .padding(.bottom, showsExpansionChrome ? Constants.Layout.Spacing.medium : Constants.Layout.Spacing.extraLarge)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .background(
            Constants.Colors.background
                .ignoresSafeArea(edges: .bottom)
        )
        .clipShape(expansionClipShape)
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: -6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Spot preview"))
    }

    private var expansionClipShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: Constants.MapDesign.mapDrawerTopCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Constants.MapDesign.mapDrawerTopCornerRadius,
            style: .continuous
        )
    }

    /// Grabber, optional profile header; swipe-down-to-dismiss and detent drags.
    private var drawerTopSection: some View {
        VStack(spacing: 0) {
            if showsExpansionChrome, let binding = drawerDetent {
                grabberRow(detent: binding)
            }
            if showsProfileChromeHeader {
                header
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 22)
                .onEnded { value in
                    handleDrawerVerticalDragEnd(translation: value.translation)
                }
        )
    }

    private func grabberRow(detent: Binding<MapSpotDrawerDetent>) -> some View {
        let spring = Animation.spring(
            response: Constants.MapDesign.selectSpringResponse,
            dampingFraction: Constants.MapDesign.selectSpringDamping
        )
        return Capsule()
            .fill(Constants.Colors.primary.opacity(0.22))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Spot preview drawer")
            .accessibilityHint("Swipe down to close. Double tap to expand or collapse.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("map.spotPreviewClose")
            .onTapGesture {
                toggleDetent(detent: detent, animation: spring)
            }
    }

    private func toggleDetent(detent: Binding<MapSpotDrawerDetent>, animation: Animation) {
        withAnimation(animation) {
            detent.wrappedValue = detent.wrappedValue == .peek ? .expanded : .peek
        }
    }

    /// Large downward swipe dismisses the drawer (`onClose` → discovery map restores prior region).
    private func handleDrawerVerticalDragEnd(translation: CGSize) {
        let dy = translation.height
        let spring = Animation.spring(
            response: Constants.MapDesign.selectSpringResponse,
            dampingFraction: Constants.MapDesign.selectSpringDamping
        )
        if dy > 100 {
            onClose()
            return
        }
        guard let detent = drawerDetent else { return }
        withAnimation(spring) {
            if dy < -40 {
                detent.wrappedValue = .expanded
            } else if dy > 48, detent.wrappedValue == .expanded {
                detent.wrappedValue = .peek
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                if let onBackToAll {
                    Button(action: onBackToAll) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back to all spots")
                                .font(FontManager.buttonText())
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if !showsExpansionChrome {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Constants.Colors.primary)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map.spotPreviewClose")
                }
            }
            .padding(.horizontal, Constants.Layout.Spacing.large)
        }
        .frame(height: 36)
        .padding(.top, 4)
    }
}

// MARK: - Previews

#Preview("Map preview – discovery") {
    let sample = Spot(
        id: "preview-discovery",
        userId: "u1",
        username: "eddie",
        userProfileImageURL: nil,
        imageURL: "https://picsum.photos/seed/spot1/800/600",
        thumbnailURL: nil,
        vibeTag: "Hidden Gem",
        latitude: 40.7128,
        longitude: -74.0060,
        locationName: "New York, NY",
        likes: 12,
        isLiked: false,
        isSaved: false,
        createdAt: Date(),
        authorIsPrivate: false
    )
    let auth = AuthViewModel()
    return MapSpotPreviewCard(
        spot: sample,
        source: "MapPreview",
        onClose: {}
    )
    .environmentObject(auth)
    .frame(maxWidth: .infinity, maxHeight: 380)
    .background(Constants.Colors.accent)
}

#Preview("Map preview – expansion chrome") {
    struct Stateful: View {
        @State private var detent = MapSpotDrawerDetent.peek
        var body: some View {
            let sample = Spot(
                id: "preview-exp",
                userId: "u1",
                username: "eddie",
                userProfileImageURL: nil,
                imageURL: "https://picsum.photos/seed/exp/800/600",
                thumbnailURL: nil,
                vibeTag: "Park",
                latitude: 25.76,
                longitude: -80.19,
                locationName: "Miami",
                likes: 1,
                isLiked: false,
                isSaved: false,
                createdAt: Date(),
                authorIsPrivate: false
            )
            let auth = AuthViewModel()
            return MapSpotPreviewCard(
                spot: sample,
                source: "MapPreview",
                onClose: {},
                drawerDetent: $detent
            )
            .environmentObject(auth)
            .frame(maxWidth: .infinity, maxHeight: detent == .expanded ? 700 : 320)
            .background(Constants.Colors.accent)
        }
    }
    return Stateful()
}

#Preview("Map preview – profile w/ back") {
    let sample = Spot(
        id: "preview-profile",
        userId: "u1",
        username: "eddie",
        userProfileImageURL: nil,
        imageURL: "https://picsum.photos/seed/spot2/800/600",
        thumbnailURL: nil,
        vibeTag: "Sunset View",
        latitude: 25.7617,
        longitude: -80.1918,
        locationName: "Miami Beach",
        likes: 5,
        isLiked: true,
        isSaved: false,
        createdAt: Date(),
        authorIsPrivate: false
    )
    let auth = AuthViewModel()
    return MapSpotPreviewCard(
        spot: sample,
        allowDelete: true,
        source: "ProfileMapPreview",
        onBackToAll: {},
        onClose: {},
        onDelete: {}
    )
    .environmentObject(auth)
    .frame(maxWidth: .infinity, maxHeight: 320)
    .background(Constants.Colors.background)
}

#Preview("Map preview – narrow width") {
    let sample = Spot(
        id: "preview-narrow",
        userId: "u1",
        username: "VeryLongUsernameThatMustTruncateCleanly",
        userProfileImageURL: nil,
        imageURL: "https://picsum.photos/seed/spotnarrow/800/600",
        thumbnailURL: nil,
        vibeTag: "Romantic",
        latitude: 25.7617,
        longitude: -80.1918,
        locationName: "Very Long Location Name That Should Not Overflow",
        likes: 3,
        isLiked: false,
        isSaved: true,
        createdAt: Date()
    )
    let auth = AuthViewModel()
    return MapSpotPreviewCard(
        spot: sample,
        source: "MapPreviewNarrow",
        onClose: {}
    )
    .environmentObject(auth)
    .frame(width: 320)
    .frame(maxHeight: 380)
    .background(Constants.Colors.background)
}

#Preview("Map preview – constrained height") {
    let sample = Spot(
        id: "preview-tight",
        userId: "u1",
        username: "eddie",
        userProfileImageURL: nil,
        imageURL: "https://picsum.photos/seed/spot3/800/600",
        thumbnailURL: nil,
        vibeTag: "Romantic",
        latitude: 25.7617,
        longitude: -80.1918,
        locationName: "Bayfront",
        likes: 220,
        isLiked: false,
        isSaved: true,
        createdAt: Date()
    )
    let auth = AuthViewModel()
    return MapSpotPreviewCard(
        spot: sample,
        source: "MapPreviewTight",
        onClose: {}
    )
    .environmentObject(auth)
    .frame(maxWidth: .infinity, maxHeight: 220)
    .background(Constants.Colors.background)
}
