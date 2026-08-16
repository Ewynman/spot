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

private struct MenuButtonAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct SpotMenuSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

enum SpotMenuPlacement {
    static func center(
        buttonFrame: CGRect,
        menuSize: CGSize,
        containerSize: CGSize,
        margin: CGFloat = 8
    ) -> CGPoint {
        let width = max(menuSize.width, 150)
        let height = max(menuSize.height, 44)
        let minX = width / 2 + margin
        let maxX = max(minX, containerSize.width - width / 2 - margin)
        let x = min(max(buttonFrame.midX, minX), maxX)
        let fitsBelow = buttonFrame.maxY + margin + height <= containerSize.height
        let proposedY = fitsBelow
            ? buttonFrame.maxY + margin + height / 2
            : buttonFrame.minY - margin - height / 2
        let minY = height / 2 + margin
        let maxY = max(minY, containerSize.height - height / 2 - margin)
        return CGPoint(x: x, y: min(max(proposedY, minY), maxY))
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

enum SpotCardPresentation: Equatable {
    case legacy
    case homePlaceFirst
}

/// Home owns a place-first presentation while the legacy `SpotCard` remains
/// the shared detail presentation for Profile, Search, collections and links.
struct HomeSpotCard: View {
    let spot: Spot
    let userId: String?
    var onDelete: (() -> Void)?
    var onImageFailure: ((Spot) -> Void)?
    var onImageRetry: ((Spot) -> Void)?
    var onOpenInMap: ((Spot) -> Void)?

    var body: some View {
        SpotCard(
            spot: spot,
            showUserInfo: true,
            userId: userId,
            onDelete: onDelete,
            source: "Feed",
            onImageFailure: onImageFailure,
            onImageRetry: onImageRetry,
            mediaPresentation: .feed,
            presentation: .homePlaceFirst,
            onOpenInMap: onOpenInMap
        )
    }
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
    var presentation: SpotCardPresentation = .legacy
    var onOpenInMap: ((Spot) -> Void)?
    @State private var measuredContentWidth: CGFloat = SpotMediaAspectRatio.estimatedFeedContentWidth()
    @State private var showDeleteConfirm: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showReportSheet: Bool = false
    @State private var showCollectionPicker: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showCustomMenu: Bool = false
    /// Seeded so the first open isn't placed with a zero-height estimate.
    @State private var menuSize: CGSize = CGSize(width: 170, height: 160)
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
    @State private var committedGalleryIndex: Int = 0
    @State private var sheetActiveVibeLabel: String?
    @State private var toastMessage: String?
    @State private var toastShowsCollectionAction = false
    @State private var collectionMembershipCount: Int?
    @State private var showRemoveSavedConfirmation = false
    @State private var homeCardModel: HomeSpotCardModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        mediaPresentation: SpotMediaPresentationContext = .feed,
        presentation: SpotCardPresentation = .legacy,
        onOpenInMap: ((Spot) -> Void)? = nil
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
        self.presentation = presentation
        self.onOpenInMap = onOpenInMap
        _currentSpot = State(initialValue: spot)
        _isSaved = State(initialValue: spot.isSaved ?? false)
        _homeCardModel = State(initialValue: HomeSpotCardModel(spotId: spot.safeId))
    }

    private var authorDisplay: SpotAuthorDisplay {
        SpotAuthorDisplay.resolve(
            spotUsername: currentSpot.username,
            spotProfileImageURL: currentSpot.userProfileImageURL,
            isCurrentUser: currentSpot.userId == authVM.userId,
            currentUsername: authVM.currentUserUsername,
            currentProfileImageURL: authVM.currentUserProfileImageURL
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if presentation == .homePlaceFirst {
                homeFaces
            } else {
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
            }
            if presentation == .homePlaceFirst {
                Divider()
                    .overlay(Constants.Colors.primary.opacity(0.10))
                    .padding(.horizontal, -12)
            }
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
        .shadow(
            color: presentation == .homePlaceFirst ? Constants.Colors.primary.opacity(0.08) : .clear,
            radius: 8,
            y: 3
        )
        .measure(target: .spotCard)
        .accessibilityIdentifier(presentation == .homePlaceFirst ? "home.spotCard" : "spot.card")
        .onChange(of: currentSpot.id) { _, _ in
            thumbnailFailed = false
            reportedImageFailure = false
            retryToken = UUID()
            homeCardModel.reset(for: currentSpot.safeId)
        }
        .onChange(of: spot.feedRowSyncToken) { _, _ in
            currentSpot = spot
            homeCardModel.reset(for: spot.safeId)
            thumbnailFailed = false
            reportedImageFailure = false
            retryToken = UUID()
            isLiked = authVM.likedSpots.contains(spot.safeId)
            isSaved = authVM.bookmarkedSpots.contains(spot.safeId)
        }
        .onChange(of: authVM.bookmarkedSpots) { _, bookmarkedSpots in
            isSaved = bookmarkedSpots.contains(currentSpot.safeId)
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
        .overlayPreferenceValue(MenuButtonAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showCustomMenu, let anchor {
                    let buttonFrame = proxy[anchor]
                    customMenuOverlay(
                        buttonFrame: buttonFrame,
                        containerSize: proxy.size
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showDeleteConfirm) {
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                deleteConfirmationOverlay
            }
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showRemoveSavedConfirmation) {
            ZStack {
                Color.clear.ignoresSafeArea()
                removeSavedConfirmationOverlay
            }
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(spot: currentSpot)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(spot: currentSpot)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showCollectionPicker) {
            CollectionManagerSheet(
                spotId: currentSpot.safeId,
                onDone: { showCollectionPicker = false },
                onMembershipChange: { collectionMembershipCount = $0 }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEditSheet) {
            EditSpotView(spot: currentSpot) { updatedSpot in
                currentSpot = updatedSpot
            }
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showVibeTagsSheet, onDismiss: {
            AnalyticsService.shared.logEvent(Constants.Analytics.vibeSheetClosed, parameters: [
                "post_id": currentSpot.safeId,
                "vibe_display_mode": currentSpot.resolvedVibeDisplayMode.rawValue
            ])
            sheetActiveVibeLabel = nil
        }) {
            VibeTagsSheet(
                labels: currentSpot.vibeLabelsForSheet(),
                activeLabel: sheetActiveVibeLabel
            )
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                if toastMessage == "Couldn't save spot" || toastMessage == "Couldn't remove saved spot" {
                    ToastView(message: toastMessage, isError: true)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    SuccessToastView(
                        message: toastMessage,
                        actionTitle: toastShowsCollectionAction ? "Add to collection" : nil,
                        action: toastShowsCollectionAction ? openCollectionManager : nil
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Split sections to help type-checker

    private var homeFaces: some View {
        ZStack {
            homeFrontFace
                .opacity(homeCardModel.face == .photo ? 1 : 0)
                .rotation3DEffect(
                    .degrees(homeCardModel.face == .photo || reduceMotion ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.65
                )
                .accessibilityHidden(homeCardModel.face != .photo)

            homeBackFace
                .opacity(homeCardModel.face == .map ? 1 : 0)
                .rotation3DEffect(
                    .degrees(homeCardModel.face == .map || reduceMotion ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.65
                )
                .accessibilityHidden(homeCardModel.face != .map)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SpotCardContentWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(SpotCardContentWidthKey.self) { width in
            if width > 1 { measuredContentWidth = width }
        }
        .measure(target: .spotDetails)
    }

    private var homeFrontFace: some View {
        VStack(alignment: .leading, spacing: 12) {
            homePlaceHeader
            spotImage
            contributorRow
                .frame(height: 44)
        }
    }

    private var homeBackFace: some View {
        VStack(alignment: .leading, spacing: 12) {
            homePlaceHeader
            HomeSpotMapPreview(
                spot: currentSpot,
                width: resolvedMediaWidth,
                height: resolvedMediaHeight,
                onOpen: openCurrentSpotInMap
            )
            .frame(width: resolvedMediaWidth, height: resolvedMediaHeight)
            .frame(maxWidth: .infinity)

            Group {
                if let context = homeLocationContext {
                    Text(context)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary.opacity(0.72))
                        .lineLimit(2)
                        .accessibilityLabel(context)
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private var homePlaceHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(homePlaceTitle)
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)
                moreActionsButton
                    .offset(y: -8)
            }

            if let locality = homeLocality {
                Text(locality)
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary.opacity(0.68))
                    .lineLimit(1)
                    .measure(target: .location)
            }

            let cardVibes = currentSpot.visibleVibeLabelsForCard()
            if !cardVibes.isEmpty {
                RotatingVibeTags(
                    labels: cardVibes,
                    syncedLabel: currentSpot.resolvedVibeDisplayMode == .photoSynced
                        ? currentSpot.cardVibeLabel(forCommittedPhotoIndex: committedGalleryIndex)
                        : nil,
                    isPaused: showVibeTagsSheet,
                    onTap: openVibeSheet
                )
                .fixedSize(horizontal: true, vertical: false)
                .measure(target: .vibeTag)
            }
        }
    }

    @ViewBuilder private var contributorRow: some View {
        if showUserInfo, let authorId = currentSpot.userId {
            NavigationLink(value: Route.profile(authorId)) {
                HStack(spacing: 8) {
                    authorAvatar
                    Text("shared by")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary.opacity(0.62))
                    Text(authorDisplay.username)
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                        .lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                FeedEventService.record(.profileTap, spotId: currentSpot.id, metadata: ["targetUserId": authorId])
            })
            .measure(target: .creator)
        }
    }

    @ViewBuilder private var authorAvatar: some View {
        if let value = authorDisplay.profileImageURL, let url = URL(string: value) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Constants.Colors.accent)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Constants.Colors.accent)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Constants.Colors.primary)
                }
        }
    }

    private var homePlaceTitle: String {
        SpotPlaceFormatting.title(for: currentSpot)
    }

    private var homeLocality: String? {
        SpotPlaceFormatting.locality(for: currentSpot)
    }

    private var homeLocationContext: String? {
        SpotPlaceFormatting.geographicContext(for: currentSpot)
    }

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
                        if let urlString = authorDisplay.profileImageURL,
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

                        Text(authorDisplay.username)
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
        SpotLocationDisplay.cityState(from: raw)
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
                galleryIdentity: currentSpot.safeId,
                isPagingEnabled: !showVibeTagsSheet,
                onPageCommitted: { index in
                    let previous = committedGalleryIndex
                    committedGalleryIndex = index
                    if currentSpot.resolvedVibeDisplayMode == .photoSynced, previous != index {
                        let vibe = currentSpot.cardVibeLabel(forCommittedPhotoIndex: index)
                        AnalyticsService.shared.logEvent(Constants.Analytics.syncedPhotoChanged, parameters: [
                            "post_id": currentSpot.safeId,
                            "active_image_index": index,
                            "active_vibe_id": vibe ?? "",
                            "vibe_display_mode": "photo_synced"
                        ])
                        if let vibe {
                            AnalyticsService.shared.logEvent(Constants.Analytics.syncedVibeChanged, parameters: [
                                "post_id": currentSpot.safeId,
                                "active_image_index": index,
                                "active_vibe_id": vibe
                            ])
                        }
                    }
                }
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
            HStack(spacing: 8) {
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
                        .font(.system(size: presentation == .homePlaceFirst ? 18 : 22))
                        .foregroundColor(isLiked ? .red : .gray)
                        .frame(width: 44, height: 44)
                        .measure(target: .likeButton)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isLiked ? "Unlike spot" : "Like spot")
                .accessibilityIdentifier(presentation == .homePlaceFirst ? "home.spotCard.like" : "spot.like")

                if presentation == .homePlaceFirst {
                    Spacer()
                }

                Button {
                    handleBookmarkTap()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: presentation == .homePlaceFirst ? 18 : 22))
                        .foregroundColor(isSaved ? Constants.Colors.primary : .gray)
                        .frame(width: 44, height: 44)
                        .measure(target: .bookmarkButton)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoadingSave)
                .accessibilityLabel(isSaved ? "Remove saved spot" : "Save spot")
                .accessibilityIdentifier("spot.bookmark")

                if presentation == .homePlaceFirst {
                    Spacer()

                    Button(action: toggleHomeFace) {
                        Group {
                            if homeCardModel.face == .photo {
                                Image("green_marker")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 18))
                                    .foregroundColor(Constants.Colors.primary)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .measure(target: .mapFlip)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasValidMapCoordinate || homeCardModel.isTransitioning)
                    .opacity(hasValidMapCoordinate ? 1 : 0.35)
                    .accessibilityLabel(homeCardModel.face == .photo ? "Show spot on map" : "Return to photo")
                    .accessibilityIdentifier("home.spotCard.flip")
                }

                if presentation == .legacy {
                    moreActionsButton
                }
            }
            .frame(maxWidth: presentation == .homePlaceFirst ? .infinity : nil)

            if presentation == .legacy {
                Spacer()

                let cardVibes = currentSpot.visibleVibeLabelsForCard()
                if !cardVibes.isEmpty {
                    let synced: String? = currentSpot.resolvedVibeDisplayMode == .photoSynced
                        ? currentSpot.cardVibeLabel(forCommittedPhotoIndex: committedGalleryIndex)
                        : nil
                    RotatingVibeTags(
                        labels: cardVibes,
                        syncedLabel: synced,
                        isPaused: showVibeTagsSheet,
                        onTap: openVibeSheet
                    )
                    .fixedSize(horizontal: true, vertical: false)
                    .measure(target: .vibeTag)
                }
            }
        }
        .padding(.horizontal, presentation == .homePlaceFirst ? 0 : 4)
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

    private var moreActionsButton: some View {
        Button {
            SpotLogger.log(SpotCardLogs.menuTapped, details: [
                "spotId": currentSpot.safeId,
                "source": source
            ])
            showCustomMenu = true
        } label: {
            Text("⋮")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Constants.Colors.primary)
                .frame(width: 44, height: 44, alignment: .center)
                .contentShape(Rectangle())
                .accessibilityLabel("More actions")
        }
        .buttonStyle(.plain)
        .anchorPreference(key: MenuButtonAnchorKey.self, value: .bounds) { $0 }
    }

    private var hasValidMapCoordinate: Bool {
        SpotPlaceFormatting.coordinate(for: currentSpot) != nil
    }

    private func toggleHomeFace() {
        guard hasValidMapCoordinate else {
            SpotLogger.log(SpotCardLogs.invalidMapCoordinate, details: [
                "source": source,
                "spotId": currentSpot.safeId,
                "reason": "invalid_map_coordinate"
            ])
            return
        }

        var next = homeCardModel
        guard next.beginToggle() else { return }
        let showingMap = next.face == .map
        let duration = reduceMotion ? 0.18 : 0.32
        withAnimation(.easeInOut(duration: duration)) {
            homeCardModel = next
        }
        AnalyticsService.shared.logEvent(
            showingMap ? "home_spot_flip_to_map" : "home_spot_flip_to_photo",
            parameters: [
                "spot_id": currentSpot.safeId,
                "source": "home",
                "has_description": homeLocationContext != nil
            ]
        )
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            homeCardModel.completeToggle()
        }
    }

    private func openCurrentSpotInMap() {
        guard hasValidMapCoordinate else { return }
        AnalyticsService.shared.logEvent("home_spot_open_in_map", parameters: [
            "spot_id": currentSpot.safeId,
            "source": "home"
        ])
        onOpenInMap?(currentSpot)
    }

    private func openVibeSheet(_ visible: String) {
        let cardVibes = currentSpot.visibleVibeLabelsForCard()
        FeedEventService.record(.vibeTap, spotId: currentSpot.id, metadata: ["vibe": visible])
        sheetActiveVibeLabel = visible
        showVibeTagsSheet = true
        AnalyticsService.shared.logEvent(Constants.Analytics.vibeSheetOpened, parameters: [
            "post_id": currentSpot.safeId,
            "image_count": currentSpot.mediaCount ?? (currentSpot.imageURLs?.count ?? 1),
            "vibe_count": cardVibes.count,
            "vibe_display_mode": currentSpot.resolvedVibeDisplayMode.rawValue,
            "active_vibe_id": visible
        ])
    }

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
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
    private func customMenuOverlay(buttonFrame: CGRect, containerSize: CGSize) -> some View {
        ZStack {
            // Tappable background to dismiss
            Color.black.opacity(0.001)
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .onTapGesture { showCustomMenu = false }

            customMenuContent
                .background {
                    GeometryReader { menuProxy in
                        Color.clear.preference(
                            key: SpotMenuSizeKey.self,
                            value: menuProxy.size
                        )
                    }
                }
                .position(
                    SpotMenuPlacement.center(
                        buttonFrame: buttonFrame,
                        menuSize: menuSize,
                        containerSize: containerSize
                    )
                )
        }
        .onPreferenceChange(SpotMenuSizeKey.self) { menuSize = $0 }
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

            if authVM.isPro && isSaved {
                Divider()

                Button {
                    showCustomMenu = false
                    openCollectionManager()
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Manage collections")
                            .font(FontManager.primaryText())
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .padding(12)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("spot.manageCollections")
            }

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
        .frame(width: 170)
    }

    private func handleBookmarkTap() {
        guard !isLoadingSave, currentSpot.id != nil, authVM.userId != nil else { return }
        if isSaved {
            prepareToRemoveSavedSpot()
        } else {
            persistSavedState(true)
        }
    }

    private func prepareToRemoveSavedSpot() {
        if let collectionMembershipCount {
            if collectionMembershipCount > 0 {
                showRemoveSavedConfirmation = true
            } else {
                persistSavedState(false)
            }
            return
        }

        isLoadingSave = true
        Task { @MainActor in
            do {
                let ids = try await BookmarksCollectionsService.shared.collectionIds(containing: currentSpot.safeId)
                collectionMembershipCount = ids.count
                isLoadingSave = false
                if ids.isEmpty {
                    persistSavedState(false)
                } else {
                    showRemoveSavedConfirmation = true
                }
            } catch {
                isLoadingSave = false
                showToast("Couldn't remove saved spot")
            }
        }
    }

    private func persistSavedState(_ target: Bool) {
        guard let spotId = currentSpot.id, !isLoadingSave else { return }
        let previous = isSaved

        isSaved = target
        isLoadingSave = true
        updateBookmarkCache(spotId: spotId, isSaved: target)

        Task { @MainActor in
            do {
                try await UserSpotService.shared.setBookmark(spotId: spotId, isSaved: target)
                isLoadingSave = false
                if !target {
                    collectionMembershipCount = 0
                }
                showToast(target ? "Saved" : "Removed from saved", collectionAction: target && authVM.isPro)
            } catch {
                isSaved = previous
                isLoadingSave = false
                updateBookmarkCache(spotId: spotId, isSaved: previous)
                showToast(target ? "Couldn't save spot" : "Couldn't remove saved spot")
            }
        }
    }

    private func updateBookmarkCache(spotId: String, isSaved: Bool) {
        if isSaved {
            if !authVM.bookmarkedSpots.contains(spotId) {
                authVM.bookmarkedSpots.append(spotId)
            }
        } else {
            authVM.bookmarkedSpots.removeAll { $0 == spotId }
        }
    }

    private func openCollectionManager() {
        guard authVM.isPro, isSaved else { return }
        toastMessage = nil
        showCollectionPicker = true
        AnalyticsService.shared.trackUserAction(
            "collection_picker_opened",
            contentType: "spot",
            contentId: currentSpot.safeId
        )
    }

    private func showToast(_ message: String, collectionAction: Bool = false) {
        toastShowsCollectionAction = collectionAction
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                    toastShowsCollectionAction = false
                }
            }
        }
    }

    private var removeSavedConfirmationOverlay: some View {
        CustomConfirmationDialog(
            title: "Remove from saved?",
            message: "This spot is in \(collectionMembershipCount ?? 0) \((collectionMembershipCount ?? 0) == 1 ? "collection" : "collections"). Removing it will also remove it from those collections.",
            confirmTitle: "Remove",
            cancelTitle: "Cancel",
            onConfirm: {
                showRemoveSavedConfirmation = false
                persistSavedState(false)
            },
            onCancel: {
                showRemoveSavedConfirmation = false
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spot.removeSavedConfirmation")
    }
}
