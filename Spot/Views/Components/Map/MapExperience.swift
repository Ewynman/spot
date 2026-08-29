//
//  MapExperience.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import MapKit
import CoreLocation

enum MapExperienceMode: Equatable {
    case global
    case profile(username: String, spotCount: Int, avatarURL: String?, isPro: Bool)
}

struct MapExperience: View {
    let mode: MapExperienceMode
    let spots: [Spot]
    @Binding var cameraIntent: SharedSpotMapCameraIntent
    var filter: SpotMapFilterState = .empty
    var savedSpotIds: Set<String> = []
    var likedSpotIds: Set<String> = []
    var followedUserIds: Set<String> = []
    var userMarker: SpotUserLocationAnnotation? = nil
    var suppressDefaultUserDot: Bool = true
    var allowDelete: Bool = false

    var onRegionChanged: (MKCoordinateRegion) -> Void = { _ in }
    var onSpotSelected: ((Spot) -> Void)? = nil
    var onSpotDeselected: (() -> Void)? = nil
    var onDeleteSpot: ((Spot) -> Void)? = nil
    var onBackFromProfile: (() -> Void)? = nil
    /// When set to a new token, clears the compact preview (filter sync, tab leave).
    var clearSelectionToken: Int = 0
    /// Internal main-tab routing request. Each request token is applied once.
    var focusRequest: MapFocusRequest? = nil

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedSpot: Spot?
    @State private var lastClearToken: Int = 0
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var carouselSpots: [Spot] = []
    @State private var carouselIndex: Int = 0
    @State private var showDetail = false
    @State private var programmaticCameraSuppressUntil: Date?
    @State private var previewRegionBaseline: MKCoordinateRegion?
    @State private var lastAppliedFocusRequestID: UUID?

    private var surface: MapAnalyticsSurface {
        switch mode {
        case .global: return .global
        case .profile: return .profile
        }
    }

    private var activePreviewSpot: Spot? {
        if !carouselSpots.isEmpty {
            let idx = min(max(carouselIndex, 0), carouselSpots.count - 1)
            return carouselSpots[idx]
        }
        return selectedSpot
    }

    private var hasPreview: Bool {
        selectedSpot != nil || !carouselSpots.isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                SharedSpotMap(
                    spots: spots,
                    selectedSpotId: selectedSpot?.id,
                    filter: filter,
                    savedSpotIds: savedSpotIds,
                    likedSpotIds: likedSpotIds,
                    followedUserIds: followedUserIds,
                    userMarker: userMarker,
                    suppressDefaultUserDot: suppressDefaultUserDot,
                    cameraIntent: cameraIntent,
                    analyticsSurface: surface,
                    onSelect: { spot, coord, region in
                        selectSpot(spot, coordinate: coord, regionAtTap: region, geo: geo)
                    },
                    onDeselect: {
                        dismissPreview(reason: "empty_map_tap", animated: true)
                    },
                    onRegionChanged: { region in
                        handleRegionChanged(region)
                    },
                    onCoincidentCluster: { members in
                        presentCarousel(members, geo: geo)
                    },
                    onClusterTapped: { count in
                        MapAnalytics.clusterTapped(surface: surface, memberCount: count)
                    }
                )
                .ignoresSafeArea()
                .accessibilityIdentifier("map.mapView")

                if case let .profile(username, spotCount, avatarURL, isPro) = mode {
                    VStack {
                        ProfileMapChrome(
                            username: username,
                            spotCount: spotCount,
                            avatarURL: avatarURL,
                            isPro: isPro,
                            onBack: { onBackFromProfile?() }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        Spacer()
                    }
                    .zIndex(8)
                }

                if let spot = activePreviewSpot {
                    previewOverlay(spot: spot, geo: geo)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                        .zIndex(5)
                }
            }
            .coordinateSpace(name: "mapCanvas")
            .onChange(of: clearSelectionToken) { _, token in
                guard token != lastClearToken else { return }
                lastClearToken = token
                dismissPreview(reason: "external_clear", animated: true)
            }
            .onAppear {
                applyFocusRequestIfNeeded(geo: geo)
            }
            .onChange(of: focusRequest?.id) { _, _ in
                applyFocusRequestIfNeeded(geo: geo)
            }
        }
        .sheet(item: detailSpotBinding) { spot in
            SpotDetailSheet(
                spot: spot,
                surface: surface,
                allowDelete: allowDelete,
                onDelete: {
                    onDeleteSpot?(spot)
                    dismissPreview(reason: "deleted", animated: false)
                },
                onDismiss: {}
            )
            .environmentObject(authVM)
            .presentationDetents([.fraction(0.82), .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Bridges `showDetail` + `activePreviewSpot` into an `item` sheet.
    private var detailSpotBinding: Binding<Spot?> {
        Binding(
            get: { showDetail ? activePreviewSpot : nil },
            set: { newValue in
                showDetail = newValue != nil
            }
        )
    }

    // MARK: - Preview overlay

    @ViewBuilder
    private func previewOverlay(spot: Spot, geo: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            if carouselSpots.count > 1 {
                carouselChrome
            }
            SpotPreviewCard(
                spot: spot,
                surface: surface,
                onOpenDetail: {
                    MapAnalytics.previewOpened(surface: surface, spotId: spot.id)
                    showDetail = true
                }
            )
            .padding(.horizontal, Constants.MapDesign.compactPreviewHorizontalInset)
            .padding(.bottom, Constants.MapDesign.compactPreviewBottomGap + max(geo.safeAreaInsets.bottom, 0))
            .id(spot.id ?? spot.safeId)
        }
        .animation(
            .spring(
                response: Constants.MapDesign.selectSpringResponse,
                dampingFraction: Constants.MapDesign.selectSpringDamping
            ),
            value: spot.id
        )
    }

    private var carouselChrome: some View {
        HStack(spacing: 12) {
            Button {
                carouselIndex = max(0, carouselIndex - 1)
                if let s = activePreviewSpot { selectedSpot = s }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(carouselIndex <= 0)

            Text("\(carouselIndex + 1) of \(carouselSpots.count)")
                .font(FontManager.buttonText())
                .foregroundColor(Constants.Colors.buttonText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Constants.Colors.primary.opacity(0.85)))

            Button {
                carouselIndex = min(carouselSpots.count - 1, carouselIndex + 1)
                if let s = activePreviewSpot { selectedSpot = s }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(carouselIndex >= carouselSpots.count - 1)
        }
        .foregroundColor(Constants.Colors.primary)
    }

    // MARK: - Selection

    private func selectSpot(
        _ spot: Spot,
        coordinate: CLLocationCoordinate2D,
        regionAtTap: MKCoordinateRegion,
        geo: GeometryProxy,
        source: String = "marker_tap"
    ) {
        carouselSpots = []
        carouselIndex = 0
        withAnimation(
            reduceMotion ? .easeInOut(duration: 0.12) :
                .spring(
                    response: Constants.MapDesign.selectSpringResponse,
                    dampingFraction: Constants.MapDesign.selectSpringDamping
                )
        ) {
            selectedSpot = spot
            selectedCoordinate = coordinate
        }
        previewRegionBaseline = nil
        scheduleProgrammaticCameraSuppression()
        focusCamera(on: coordinate, geo: geo)
        onSpotSelected?(spot)
        if source == "marker_tap" {
            let markerType: MapMarkerAnalyticsType = SpotPhotoPinSource.imageURL(for: spot) != nil
                && MapMarkerFeatureFlags.photoPinMarkersEnabled
                ? .photoPin
                : .teardrop
            MapAnalytics.markerTapped(
                surface: surface,
                spotId: spot.id,
                markerType: markerType,
                zoomLevel: SpotAnnotationZoom.approximateZoomLevel(for: regionAtTap)
            )
            FeedEventService.record(.mapPinTap, spotId: spot.id)
        }
        MapAnalytics.previewShown(surface: surface, spotId: spot.id)
        SpotLogger.log(MapViewLogs.homeSheetOpen, details: [
            "surface": surface.rawValue,
            "spotId": spot.id ?? "nil",
            "source": source
        ])
        FeedEventService.record(.detailOpen, spotId: spot.id, metadata: ["surface": "map_preview"])
    }

    private func applyFocusRequestIfNeeded(geo: GeometryProxy) {
        guard let request = focusRequest,
              request.id != lastAppliedFocusRequestID else { return }
        lastAppliedFocusRequestID = request.id
        selectSpot(
            request.spot,
            coordinate: request.coordinate,
            regionAtTap: MKCoordinateRegion(
                center: request.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)
            ),
            geo: geo,
            source: request.source.rawValue
        )
    }

    private func presentCarousel(_ members: [Spot], geo: GeometryProxy) {
        guard let first = members.first else { return }
        carouselSpots = members
        carouselIndex = 0
        selectedSpot = first
        if let lat = first.latitude, let lon = first.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedCoordinate = coord
            scheduleProgrammaticCameraSuppression()
            focusCamera(on: coord, geo: geo)
        }
        onSpotSelected?(first)
        MapAnalytics.previewShown(surface: surface, spotId: first.id)
    }

    private func focusCamera(on coordinate: CLLocationCoordinate2D, geo: GeometryProxy) {
        let lift = MapClusterStyle.compactPreviewCameraLift(
            cardHeight: Constants.MapDesign.compactPreviewHeight
                + Constants.MapDesign.compactPreviewBottomGap
                + geo.safeAreaInsets.bottom
        )
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        cameraIntent = .focus(
            coordinate: coordinate,
            span: span,
            liftPoints: lift,
            animated: !reduceMotion
        )
    }

    private func handleRegionChanged(_ region: MKCoordinateRegion) {
        cameraIntent = .none
        onRegionChanged(region)

        guard hasPreview else {
            previewRegionBaseline = nil
            return
        }
        if isProgrammaticCameraSuppressActive {
            previewRegionBaseline = region
            return
        }
        if let base = previewRegionBaseline {
            if MapDiscoveryDrawerPolicy.regionsMeaningfullyDiffer(base, region) {
                dismissPreview(reason: "map_moved", animated: true)
            }
        } else {
            previewRegionBaseline = region
        }
    }

    func clearSelection(reason: String = "external", animated: Bool = true) {
        dismissPreview(reason: reason, animated: animated)
    }

    private func dismissPreview(reason: String, animated: Bool) {
        guard hasPreview else { return }
        let spotId = selectedSpot?.id
        MapAnalytics.previewDismissed(surface: surface, spotId: spotId, reason: reason)
        SpotLogger.log(MapViewLogs.homeSheetClose, details: [
            "surface": surface.rawValue,
            "spotId": spotId ?? "nil",
            "reason": reason
        ])
        let apply = {
            selectedSpot = nil
            selectedCoordinate = nil
            carouselSpots = []
            carouselIndex = 0
            previewRegionBaseline = nil
            programmaticCameraSuppressUntil = nil
            showDetail = false
            // PRD: do not restore prior camera on deselect.
            cameraIntent = .none
        }
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.18), apply)
        } else {
            apply()
        }
        onSpotDeselected?()
    }

    private var isProgrammaticCameraSuppressActive: Bool {
        guard let until = programmaticCameraSuppressUntil else { return false }
        return Date() < until
    }

    private func scheduleProgrammaticCameraSuppression() {
        programmaticCameraSuppressUntil = Date().addingTimeInterval(
            MapDiscoveryDrawerPolicy.programmaticCameraSuppressionSeconds
        )
    }
}

// MARK: - Profile chrome

struct ProfileMapChrome: View {
    let username: String
    let spotCount: Int
    let avatarURL: String?
    let isPro: Bool
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Constants.Colors.background.opacity(0.95)))
                    .overlay(Circle().stroke(Constants.Colors.primary.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to profile")

            HStack(spacing: 8) {
                avatar
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(username)
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.textPrimary)
                            .lineLimit(1)
                        if isPro {
                            Text("Pro")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(Constants.Colors.buttonText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Constants.Colors.primary)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(spotCount) spots")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textPrimary.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: Constants.MapDesign.profileMapChromeHeight)
            .background(
                Capsule().fill(Constants.Colors.background.opacity(0.95))
            )
            .overlay(
                Capsule().stroke(Constants.Colors.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var avatar: some View {
        Group {
            if let avatarURL, let url = URL(string: avatarURL) {
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
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .padding(.leading, 8)
    }
}
