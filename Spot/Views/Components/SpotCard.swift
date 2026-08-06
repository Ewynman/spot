// SpotCard.swift
// Spot
//
// Created by Edward Wynman on 8/6/25.
//

import SwiftUI

// MARK: - Preference Keys

private struct SpotCardContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

struct MenuButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    let sample = Spot(
        id: "s1",
        userId: "u1",
        username: "eddie",
        userProfileImageURL: nil,
        imageURL: "https://picsum.photos/seed/spot1/800/600",
        thumbnailURL: nil,
        vibeTag: "Fishing",
        latitude: 40.7128,
        longitude: -74.0060,
        locationName: "New York, NY",
        likes: 0,
        isLiked: false,
        isSaved: false,
        createdAt: Date(),
        authorIsPrivate: false,
        imageURLs: [
            "https://picsum.photos/seed/spot1a/800/600",
            "https://picsum.photos/seed/spot1b/800/600"
        ],
        mediaDisplayAspectRatio: 800.0 / 600.0,
        mediaCount: 2
    )
    let auth = AuthViewModel()
    auth.isPro = true
    return SpotCard(spot: sample, showUserInfo: true, userId: "u1", onDelete: {}, source: "Preview")
        .environmentObject(auth)
        .padding()
        .background(Color(hex: "F5F3EF"))
}

struct SpotCard: View {
    let spot: Spot
    let showUserInfo: Bool    // show profile pic + username if true
    let userId: String?
    var onDelete: (() -> Void)?
    var source: String = "Unknown"
    var backAction: (() -> Void)?
    var backButtonText: String = "Back to profile"
    var onImageFailure: ((Spot) -> Void)?
    var onImageRetry: ((Spot) -> Void)?
    /// Controls min/max media height clamps for this host (feed vs detail vs map drawer).
    var mediaPresentation: SpotMediaPresentationContext = .feed
    @State private var measuredContentWidth: CGFloat = SpotMediaAspectRatio.estimatedFeedContentWidth()
    @State private var showDeleteConfirm: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showReportSheet: Bool = false
    @State private var showCollectionPicker: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showCustomMenu: Bool = false
    @State private var menuButtonFrame: CGRect = .zero
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var isLoadingLike = false
    @State private var isLoadingSave = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var thumbnailFailed: Bool = false
    @State private var reportedImageFailure: Bool = false
    @State private var retryToken: UUID = UUID()
    @State private var currentSpot: Spot
    @State private var showVibeTagsSheet = false

    init(
        spot: Spot,
        showUserInfo: Bool = true,
        userId: String? = nil,
        onDelete: (() -> Void)? = nil,
        source: String = "Unknown",
        backAction: (() -> Void)? = nil,
        backButtonText: String = "Back to profile",
        onImageFailure: ((Spot) -> Void)? = nil,
        onImageRetry: ((Spot) -> Void)? = nil,
        mediaPresentation: SpotMediaPresentationContext = .feed
    ) {
        self.spot = spot
        self.showUserInfo = showUserInfo
        self.userId = userId
        self.onDelete = onDelete
        self.source = source
        self.backAction = backAction
        self.backButtonText = backButtonText
        self.onImageFailure = onImageFailure
        self.onImageRetry = onImageRetry
        self.mediaPresentation = mediaPresentation
        _currentSpot = State(initialValue: spot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header
                spotImage
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: SpotCardContentWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(SpotCardContentWidthKey.self) { w in
                if w > 1 { measuredContentWidth = w }
            }
            .measure(target: .spotDetails)
            interactionBar
            if showError {
                Text(errorMessage)
                    .font(FontManager.primaryText())
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Constants.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .measure(target: .spotCard)
        .onChange(of: currentSpot.id) { _, _ in
            thumbnailFailed = false
            reportedImageFailure = false
            retryToken = UUID()
        }
        .onChange(of: spot.feedRowSyncToken) { _, _ in
            currentSpot = spot
            thumbnailFailed = false
            reportedImageFailure = false
            retryToken = UUID()
            isLiked = authVM.likedSpots.contains(spot.safeId)
            isSaved = authVM.bookmarkedSpots.contains(spot.safeId)
        }
        .onAppear {
            isLiked = authVM.likedSpots.contains(currentSpot.safeId)
            isSaved = authVM.bookmarkedSpots.contains(currentSpot.safeId)
            let currentUserId = userId ?? authVM.userId ?? ""
            let ownerId = currentSpot.userId ?? ""
            let isOwner = (!currentUserId.isEmpty && !ownerId.isEmpty && currentUserId == ownerId)
            SpotLogger.log(SpotCardLogs.spotCardAppear, details: [
                "source": source,
                "spotId": currentSpot.safeId,
                "ownerId": ownerId.isEmpty ? "nil" : ownerId,
                "currentUserId": currentUserId.isEmpty ? "nil" : currentUserId,
                "isOwner": isOwner
            ])
            if currentUserId.isEmpty || ownerId.isEmpty {
                SpotLogger.log(SpotCardLogs.ownerGateMissingInputs, details: ["source": source, "spotId": currentSpot.safeId])
            }
        }
        .overlay(
            // Custom dropdown menu overlay
            Group {
                if showCustomMenu {
                    customMenuOverlay
                }
            }
        )
        .overlay {
            if showDeleteConfirm {
                deleteConfirmationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showDeleteConfirm)
        .onPreferenceChange(MenuButtonFrameKey.self) { frame in
            menuButtonFrame = frame
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(spot: currentSpot)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(spot: currentSpot)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showCollectionPicker) {
            CollectionPickerSheet(spotId: currentSpot.safeId, onDone: { showCollectionPicker = false }) {
                // Mark as saved when user successfully saves to collection
                isSaved = true
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditSpotView(spot: currentSpot) { updatedSpot in
                currentSpot = updatedSpot
            }
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showVibeTagsSheet) {
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 42, height: 5)
                    .padding(.top, 8)
                Text("Vibe Tags")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                ForEach(currentSpot.visibleVibeLabelsForCard(), id: \.self) { tag in
                    Text(tag)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Constants.Colors.accent)
                        .cornerRadius(12)
                }
                Spacer()
            }
            .presentationDetents([.fraction(0.4)])
            .background(Constants.Colors.background)
        }
    }

    // MARK: - Split sections to help type-checker
    @ViewBuilder private var header: some View {
        HStack {
            if let backAction {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                    Text(backButtonText)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    SpotLogger.log(SpotCardLogs.backButtonTapped, details: ["spotId": currentSpot.safeId, "source": source])
                    backAction()
                }
                .zIndex(10)
            } else if showUserInfo, let userId = currentSpot.userId {
                NavigationLink(value: Route.profile(userId)) {
                    HStack(spacing: 8) {
                        // (event recorded via simultaneousGesture below)
                        if let urlString = currentSpot.userProfileImageURL,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { img in
                                img.resizable()
                                   .scaledToFill()
                                   .frame(width: 32, height: 32)
                                   .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Constants.Colors.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Constants.Colors.primary)
                                    )
                            }
                        } else {
                            Circle()
                                .fill(Constants.Colors.background)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Constants.Colors.primary)
                                )
                        }

                        Text(currentSpot.username ?? "")
                            .font(FontManager.primaryText())
                            .fontWeight(.semibold)
                            .foregroundColor(Constants.Colors.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .measure(target: .username)
                    }
                    .measure(target: .creator)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    FeedEventService.record(.profileTap, spotId: currentSpot.id, metadata: ["targetUserId": userId])
                })
            }

            Spacer()

            if let location = currentSpot.locationName, !location.isEmpty {
                Text(cityState(from: location))
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .measure(target: .location)
            }
        }
        .padding(.horizontal, 12)
    }

    private func cityState(from raw: String) -> String {
        let disallowed = Set(["united states", "usa", "us", "united states of america"])
        let parts = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { segment in
                let lower = segment.lowercased()
                if disallowed.contains(lower) { return false }
                // Drop segments that contain digits (street numbers, zip codes)
                return segment.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil
            }

        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ", ")
        } else if let first = parts.first {
            return first
        } else {
            return raw
        }
    }

    private var resolvedMediaWidth: CGFloat {
        let raw = max(measuredContentWidth, 1)
        // Map preview hosts SpotCard in a vertical ScrollView; layout can propose an effectively
        // unbounded width after expansion so geometry reads huge → media shells widen past the screen.
        guard mediaPresentation == .mapDrawer else { return raw }
        let mapHorizontalPadding = Constants.Layout.Spacing.large * 2
        let cardHorizontalPadding: CGFloat = 24
        let cap = SpotMediaLayoutMetrics.screenWidth - mapHorizontalPadding - cardHorizontalPadding
        return min(raw, max(cap, 1))
    }

    private var resolvedMediaHeight: CGFloat {
        let ratio = SpotMediaAspectRatio.effectiveDisplayRatio(for: currentSpot)
        return SpotMediaAspectRatio.mediaHeight(
            containerWidth: resolvedMediaWidth,
            displayRatio: ratio,
            minHeight: mediaPresentation.minMediaHeight,
            maxHeight: mediaPresentation.maxMediaHeight
        )
    }

    @ViewBuilder private var spotImage: some View {
        spotImageSlot(measuredWidth: resolvedMediaWidth, mediaHeight: resolvedMediaHeight)
            .frame(width: resolvedMediaWidth, height: resolvedMediaHeight)
            .frame(maxWidth: .infinity)
            .clipped()
    }

    /// Measured width keeps loaded `Image` views from inflating `ScrollView` / `TabView` content
    /// with wide intrinsic sizes (e.g. map preview drawer shifting right when the image appears).
    @ViewBuilder
    private func spotImageSlot(measuredWidth: CGFloat, mediaHeight: CGFloat) -> some View {
        if let urls = currentSpot.imageURLs, !urls.isEmpty {
            SpotImageGallery(
                urls: urls,
                fallback: currentSpot.imageURL,
                spotId: currentSpot.id,
                mediaHeight: mediaHeight,
                galleryIdentity: currentSpot.safeId
            )
        } else if let thumb = currentSpot.thumbnailURL, let turl = URL(string: thumb) {
            RemoteImage(url: turl, maxPixelSize: 1200, transaction: Transaction(animation: .default)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Constants.Colors.background)
                        .frame(width: measuredWidth, height: mediaHeight)
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(width: measuredWidth, height: mediaHeight)
                        .clipped()
                        .cornerRadius(12)
                case .failure(let failure):
                    Image("image_placeholder")
                        .resizable()
                        .scaledToFill()
                        .frame(width: measuredWidth, height: mediaHeight)
                        .clipped()
                        .cornerRadius(12)
                        .onAppear {
                            let host = URL(string: thumb)?.host ?? "unknown"
                            SpotLogger.log(SpotCardLogs.imageThumbnailLoadFailed, details: [
                                "spotId": currentSpot.safeId,
                                "source": source,
                                "thumbHost": host,
                                "thumbUrl": thumb,
                                "statusCode": failure.statusCode as Any,
                                "errorDomain": failure.nsError.domain,
                                "errorCode": failure.nsError.code,
                                "error": failure.underlying.localizedDescription,
                                "mimeType": failure.mimeType as Any,
                                "bodyPreview": failure.bodyPreview as Any
                            ])
                            thumbnailFailed = true
                            if !reportedImageFailure {
                                reportedImageFailure = true
                                onImageFailure?(currentSpot)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                retryToken = UUID(); onImageRetry?(currentSpot)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(FontManager.primaryText())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(8)
                        }
                @unknown default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Constants.Colors.background)
                        .frame(width: measuredWidth, height: mediaHeight)
                }
            }
            .id(retryToken)
        } else if let urlString = currentSpot.imageURL, let url = URL(string: urlString) {
            RemoteImage(url: url, maxPixelSize: 1200, transaction: Transaction(animation: .default)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Constants.Colors.background)
                        .frame(width: measuredWidth, height: mediaHeight)
                case .success(let image):
                    image.resizable()
                       .scaledToFill()
                       .frame(width: measuredWidth, height: mediaHeight)
                       .clipped()
                       .cornerRadius(12)
                        .onAppear {
                            SpotLogger.log(SpotCardLogs.spotImageLoaded, details: [
                                "spotId": currentSpot.safeId,
                                "source": source,
                                "hasThumb": false,
                                "url": urlString
                            ])
                        }
                case .failure(let failure):
                    Image("image_placeholder")
                        .resizable()
                        .scaledToFill()
                        .frame(width: measuredWidth, height: mediaHeight)
                        .clipped()
                        .cornerRadius(12)
                        .onAppear {
                            let host = url.host ?? "unknown"
                            SpotLogger.log(SpotCardLogs.imageFullSizeLoadFailed, details: [
                                "spotId": currentSpot.safeId,
                                "source": source,
                                "fullHost": host,
                                "fullUrl": urlString,
                                "statusCode": failure.statusCode as Any,
                                "errorDomain": failure.nsError.domain,
                                "errorCode": failure.nsError.code,
                                "error": failure.underlying.localizedDescription,
                                "mimeType": failure.mimeType as Any,
                                "bodyPreview": failure.bodyPreview as Any
                            ])
                            if !reportedImageFailure {
                                reportedImageFailure = true
                                onImageFailure?(currentSpot)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Button { retryToken = UUID(); onImageRetry?(currentSpot) } label: {
                                HStack(spacing: 6) { Image(systemName: "arrow.clockwise"); Text("Retry") }
                                    .font(FontManager.primaryText())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(8)
                        }
                @unknown default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Constants.Colors.background)
                        .frame(width: measuredWidth, height: mediaHeight)
                }
            }
            .id(retryToken)
        } else {
            Image("image_placeholder")
                .resizable()
                .scaledToFill()
                .frame(width: measuredWidth, height: mediaHeight)
                .clipped()
                .cornerRadius(12)
                .onAppear {
                    SpotLogger.log(SpotCardLogs.imagePlaceholderUsed, details: [
                        "spotId": currentSpot.safeId,
                        "source": source,
                        "hasThumb": false,
                        "url": currentSpot.imageURL ?? "nil"
                    ])
                }
        }
    }

    private var interactionBar: some View {
        // let _ is to be userId done to supress warnings
        HStack {
            HStack(spacing: 16) {
                Button {
                    guard !isLoadingLike, let spotId = currentSpot.id, authVM.userId != nil else { return }
                    isLiked.toggle()
                    isLoadingLike = true
                    if isLiked {
                        authVM.likeSpot(spotId)
                        isLoadingLike = false
                    } else {
                        authVM.unlikeSpot(spotId)
                        isLoadingLike = false
                    }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(isLiked ? .red : .gray)
                        .measure(target: .likeButton)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    guard !isLoadingSave, let spotId = currentSpot.id, authVM.userId != nil else { return }
                    if !isSaved, !authVM.isPro, authVM.bookmarkedSpots.count >= 50 {
                        NotificationCenter.default.post(name: .showPaywall, object: nil)
                        return
                    }

                    if authVM.isPro && !isSaved {
                        showCollectionPicker = true
                    } else {
                        isSaved.toggle()
                        isLoadingSave = true
                        if isSaved {
                            authVM.bookmarkSpot(spotId)
                            isLoadingSave = false
                        } else {
                            authVM.unbookmarkSpot(spotId)
                            isLoadingSave = false
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 22))
                        .foregroundColor(isSaved ? Constants.Colors.primary : .gray)
                        .measure(target: .bookmarkButton)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    SpotLogger.log(SpotCardLogs.menuTapped, details: ["spotId": currentSpot.safeId, "source": source])
                    showCustomMenu = true
                } label: {
                    Text("⋮")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Constants.Colors.primary)
                        .frame(width: 24, height: 24, alignment: .center)
                        .contentShape(Rectangle())
                        .accessibilityLabel("More actions")
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: MenuButtonFrameKey.self, value: geo.frame(in: .global))
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            let cardVibes = currentSpot.visibleVibeLabelsForCard()
            if let firstVibe = cardVibes.first {
                RotatingVibeTags(
                    labels: cardVibes,
                    onTap: {
                        FeedEventService.record(.vibeTap, spotId: currentSpot.id, metadata: ["vibe": firstVibe])
                        if cardVibes.count > 1 {
                            showVibeTagsSheet = true
                        }
                    }
                )
                .fixedSize(horizontal: true, vertical: false)
                .measure(target: .vibeTag)
            }
        }
        .padding(.leading, 16)
        .frame(width: resolvedMediaWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
        .overlay(
            GeometryReader { geo in
                let likeArea = CGRect(x: 16, y: 0, width: 80, height: geo.size.height)
                Color.clear.preference(
                    key: CoachFramesPrefKey.self,
                    value: [
                        .likeSave: geo.frame(in: .global)
                            .intersection(CGRect(origin: geo.frame(in: .global).origin, size: likeArea.size))
                    ]
                )
            }
        )
    }

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture { showDeleteConfirm = false }

            VStack(spacing: 16) {
                Text("Delete this Spot?")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)

                Text("This can’t be undone.")
                    .font(FontManager.primaryText())
                    .foregroundColor(.gray)

                HStack(spacing: 12) {
                    Button {
                        showDeleteConfirm = false
                    } label: {
                        Text("Cancel")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Constants.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Constants.Colors.primary, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("spot.deleteCancel")

                    Button {
                        showDeleteConfirm = false
                        onDelete?()
                    } label: {
                        Text("Delete")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Constants.Colors.primary)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("spot.deleteConfirm")
                }
            }
            .padding(20)
            .background(Constants.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Constants.Colors.primary.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spot.deleteConfirmation")
    }

    // MARK: - Custom Menu
    private var customMenuOverlay: some View {
        GeometryReader { _ in
            ZStack {
                // Tappable background to dismiss
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { showCustomMenu = false }

                // Position menu near the three dots button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        customMenuContent
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                    }
                }
                .offset(x: -menuButtonFrame.width - 8, y: -menuButtonFrame.height - 8)
            }
        }
    }

    private var customMenuContent: some View {
        let currentUserId = userId ?? authVM.userId ?? ""
        let ownerId = currentSpot.userId ?? ""
        let isOwner = (!currentUserId.isEmpty && !ownerId.isEmpty && currentUserId == ownerId)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                showCustomMenu = false
                SpotLogger.log(SpotCardLogs.shareTapped, details: ["spotId": currentSpot.safeId, "source": source])
                FeedEventService.record(.share, spotId: currentSpot.id)
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .font(FontManager.primaryText())
                }
                .foregroundColor(Constants.Colors.primary)
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())

            Divider()

            Button {
                showCustomMenu = false
                if authVM.isPro { showCollectionPicker = true } else { NotificationCenter.default.post(name: .showPaywall, object: nil) }
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Add to Collection")
                        .font(FontManager.primaryText())
                }
                .foregroundColor(Constants.Colors.primary)
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())

            if !isOwner {
                Divider()

                Button {
                    showCustomMenu = false
                    SpotLogger.log(SpotCardLogs.reportTapped, details: ["spotId": currentSpot.safeId, "source": source])
                    FeedEventService.record(.reportAuthor, spotId: currentSpot.id)
                    showReportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "flag")
                        Text("Report")
                            .font(FontManager.primaryText())
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .padding(12)
                }
                .buttonStyle(PlainButtonStyle())

                Divider()

                Button {
                    showCustomMenu = false
                    if let targetUserId = currentSpot.userId {
                        FeedEventService.record(.blockAuthor, spotId: currentSpot.id, metadata: ["targetUserId": targetUserId])
                        Task {
                            do {
                                try await authVM.blockUser(userId: targetUserId)
                                await MainActor.run {
                                    NotificationCenter.default.post(
                                        name: .homeFeedLocallyRemove,
                                        object: nil,
                                        userInfo: [SpotHomeFeedNotification.authorUserIdKey: targetUserId]
                                    )
                                }
                                SpotLogger.log(SpotCardLogs.userBlocked, details: ["targetUserId": targetUserId])
                            } catch {
                                SpotLogger.log(SpotCardLogs.blockUserFailed, details: ["error": error.localizedDescription])
                            }
                        }
                    }
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
            }

            if isOwner, onDelete != nil {
                Divider()

                Button {
                    showCustomMenu = false
                    if authVM.isPro { showEditSheet = true } else { NotificationCenter.default.post(name: .showPaywall, object: nil) }
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                            .font(FontManager.primaryText())
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .padding(12)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    showCustomMenu = false
                    SpotLogger.log(SpotCardLogs.deleteTapped, details: ["spotId": currentSpot.safeId, "source": source])
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                            .font(FontManager.primaryText())
                    }
                    .foregroundColor(.red)
                    .padding(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Constants.Colors.primary, lineWidth: 1)
        )
        .frame(width: 150)
    }

    // MARK: - Collection Picker Sheet
    private struct CollectionPickerSheet: View {
        let spotId: String
        var onDone: () -> Void
        var onSave: (() -> Void)? = nil
        @State private var collections: [BookmarkCollection] = []
        @State private var previews: [String: [String]] = [:]
        @State private var newName: String = ""
        @State private var isLoading: Bool = true
        @State private var showCreateModal: Bool = false

        private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        var body: some View {
            NavigationStack {
                ZStack {
                    Constants.Colors.background.ignoresSafeArea()
                    VStack(spacing: 12) {
                        if isLoading {
                            Spacer()
                            ProgressView()
                            Spacer()
                        } else {
                            ScrollView {
                                VStack(spacing: 12) {
                                    // "Just Save" button at the top
                                    Button {
                                        Task {
                                            // Just bookmark without collection
                                            await withCheckedContinuation { continuation in
                                                UserSpotService.shared.bookmarkSpot(spotId: spotId) { _ in
                                                    continuation.resume()
                                                }
                                            }
                                            onSave?()
                                            onDone()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "bookmark.fill")
                                            Text("Just Save")
                                                .font(FontManager.primaryText())
                                        }
                                        .foregroundColor(Constants.Colors.buttonText)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Constants.Colors.primary)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.top, 12)
                                    
                                    LazyVGrid(columns: grid, spacing: 12) {
                                        // "+" tile to create a new collection
                                        Button {
                                            showCreateModal = true
                                        } label: {
                                            NewCollectionTile()
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        ForEach(collections) { c in
                                            Button {
                                                Task { await add(to: c.id) }
                                            } label: {
                                                CollectionCardView(
                                                    title: c.name,
                                                    previewURLs: previews[c.id] ?? [],
                                                    count: c.spotIds.count
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Add to Collection")
                            .font(FontManager.sectionHeader())
                            .foregroundColor(Constants.Colors.primary)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { onDone() }
                            .foregroundColor(Constants.Colors.primary)
                            .buttonStyle(.plain)
                    }
                }
                .onAppear { Task { await load() } }
                .sheet(isPresented: $showCreateModal) {
                    CreateCollectionModal(newName: $newName, onCreate: {
                        Task { await create() }
                    })
                    .presentationDetents([.fraction(0.28)])
                    .presentationDragIndicator(.visible)
                }
            }
        }

        private func load() async {
            isLoading = true
            do {
                let cols = try await BookmarksCollectionsService.shared.listCollections()
                collections = cols
                await loadPreviews()
            } catch {
                collections = []
            }
            isLoading = false
        }

        private func loadPreviews() async {
            await withTaskGroup(of: (String, [String]).self) { group in
                for c in collections {
                    let ids = Array(c.spotIds.prefix(4))
                    group.addTask {
                        let urls = await fetchSpotPreviewURLs(spotIds: ids)
                        return (c.id, urls)
                    }
                }
                for await (cid, urls) in group {
                    previews[cid] = urls
                }
            }
        }

        private func fetchSpotPreviewURLs(spotIds: [String], limit: Int = 4) async -> [String] {
            let ids = Array(spotIds.prefix(limit))
            guard !ids.isEmpty else { return [] }
            let urls = await SpotSupabaseRepository.fetchPreviewImageURLs(spotIds: ids)
            return urls.filter { !$0.isEmpty }
        }

        private func create() async {
            let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            do {
                let collectionId = try await BookmarksCollectionsService.shared.createCollection(name: name)
                // Add the spot to the new collection
                try await BookmarksCollectionsService.shared.addSpot(spotId, to: collectionId)
                // Also add to bookmarks so it shows up in bookmarks view
                await withCheckedContinuation { continuation in
                    UserSpotService.shared.bookmarkSpot(spotId: spotId) { result in
                        continuation.resume()
                    }
                }
                // Notify parent that spot was saved
                onSave?()
                newName = ""
                showCreateModal = false
                await load()
            } catch { }
        }

        private func add(to collectionId: String) async {
            guard !spotId.isEmpty else { return }
            do {
                try await BookmarksCollectionsService.shared.addSpot(spotId, to: collectionId)
                // Also add to bookmarks so it shows up in bookmarks view
                await withCheckedContinuation { continuation in
                    UserSpotService.shared.bookmarkSpot(spotId: spotId) { result in
                        continuation.resume()
                    }
                }
                // Notify parent that spot was saved
                onSave?()
                // Refresh collections to update counts and previews
                await load()
                onDone()
            } catch { }
        }

        private struct NewCollectionTile: View {
            private var itemWidth: CGFloat {
                let screenWidth = UIScreen.main.bounds.width
                let padding: CGFloat = 12 * 2
                let spacing: CGFloat = 12 * 1
                return (screenWidth - padding - spacing) / 2
            }
            var body: some View {
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: itemWidth, height: itemWidth)
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Constants.Colors.primary, lineWidth: 1)
                )
            }
        }

        private struct CreateCollectionModal: View {
            @Binding var newName: String
            var onCreate: () -> Void

            var body: some View {
                VStack(spacing: 12) {
                    Text("New Collection")
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.top, 8)

                    HStack(spacing: 8) {
                        TextField("Collection Name", text: $newName)
                            .foregroundColor(Constants.Colors.primary)
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.primary, lineWidth: 1))
                        Button {
                            onCreate()
                        } label: {
                            Text("Create")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.buttonText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Constants.Colors.primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .background(Constants.Colors.background)
            }
        }
    }
}
