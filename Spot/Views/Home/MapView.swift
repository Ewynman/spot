//
//  MapView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import MapKit
import CoreLocation

@MainActor
struct MapView: View {

    @StateObject private var mapVM = MapViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @ObservedObject private var mapFocusCoordinator = MapFocusCoordinator.shared
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var permissionManager: PermissionManager

    @State private var showLocationPrePrompt: Bool = false
    @State private var cameraIntent: SharedSpotMapCameraIntent = .none
    @State private var hasPerformedInitialFit: Bool = false
    @State private var hasCenteredOnUser: Bool = false
    @State private var lastRegionFromMap: MKCoordinateRegion?
    @State private var lastCenteredCoordinate: CLLocationCoordinate2D?
    @State private var userHasMovedMap: Bool = false
    @State private var filterState: SpotMapFilterState = .empty
    @State private var showVibePicker: Bool = false
    @State private var selectedSpotId: String?
    @State private var previewBottomReserved: CGFloat = 0
    @State private var clearSelectionToken: Int = 0
    @State private var activeFocusRequest: MapFocusRequest?

    init(spots _: [Spot] = []) {}

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    MapExperience(
                        mode: .global,
                        spots: renderedSpots,
                        cameraIntent: $cameraIntent,
                        filter: filterState,
                        savedSpotIds: Set(authVM.bookmarkedSpots),
                        likedSpotIds: Set(authVM.likedSpots),
                        followedUserIds: [],
                        userMarker: userMarker,
                        suppressDefaultUserDot: true,
                        onRegionChanged: { region in
                            handleMapRegionChanged(region)
                        },
                        onSpotSelected: { spot in
                            if activeFocusRequest?.spotID != spot.id {
                                activeFocusRequest = nil
                            }
                            selectedSpotId = spot.id
                            previewBottomReserved = Constants.MapDesign.compactPreviewHeight
                                + Constants.MapDesign.compactPreviewBottomGap
                                + max(geo.safeAreaInsets.bottom, 0)
                        },
                        onSpotDeselected: {
                            activeFocusRequest = nil
                            selectedSpotId = nil
                            previewBottomReserved = 0
                        },
                        clearSelectionToken: clearSelectionToken,
                        focusRequest: activeFocusRequest
                    )
                    .ignoresSafeArea()
                    .overlay { mapOnboardingTargets }

                    MapControlsOverlay(
                        filterState: filterPillBinding,
                        availableVibeTags: Constants.VibeTags.defaultTags,
                        onOpenVibePicker: { showVibePicker = true },
                        canRecenter: shouldShowRecenterControl,
                        onRecenter: recenterOnUser,
                        bottomReservedHeight: previewBottomReserved
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(10)
                }
                .coordinateSpace(name: "mapCanvas")
                .background(Constants.Colors.background)
                .background(Constants.Colors.background.ignoresSafeArea())
                .onAppear { onAppear(geo: geo) }
                .onDisappear { onDisappear() }
                .onReceive(locationManager.$userLocation) { newValue in
                    onUserLocationReceived(newValue)
                }
                .onChange(of: permissionManager.locationStatus) { oldStatus, newStatus in
                    handleLocationAuthorizationChange(from: oldStatus, to: newStatus)
                }
                .onChange(of: filterState) { _, newValue in
                    MapAnalytics.filterChanged(dimensions: newValue.dimensions.map(\.rawValue))
                    syncMapSelectionWithActiveFilter(newValue)
                }
                .sheet(isPresented: $showVibePicker) {
                    MapVibeFilterSheet(
                        state: $filterState,
                        vibeTags: Constants.VibeTags.defaultTags,
                        onClose: { showVibePicker = false }
                    )
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showLocationPrePrompt) {
                    LocationPermissionView(
                        authDestination: .signup,
                        showsBackButton: false,
                        onComplete: {
                            showLocationPrePrompt = false
                            locationManager.requestCurrentLocationForMapTab()
                        }
                    )
                    .environmentObject(permissionManager)
                    .interactiveDismissDisabled(false)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .profile(let userId):
                    ProfileView(userId: userId, fromNavigationPush: true)
                        .navigationBarBackButtonHidden(true)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("map.screen")
        .onChange(of: mapFocusCoordinator.pendingRequest?.id) { _, requestID in
            guard let requestID else { return }
            applyPendingMapFocus(expectedID: requestID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
            guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 1 else { return }
            showVibePicker = false
            selectedSpotId = nil
            activeFocusRequest = nil
            previewBottomReserved = 0
            clearSelectionToken += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .spotDidUpdate)) { output in
            guard let updatedSpot = output.object as? Spot else { return }
            mapVM.locallyReplaceSpot(updatedSpot)
        }
    }

    private var mapOnboardingTargets: some View {
        GeometryReader { geo in
            ZStack {
                if locationManager.userLocation != nil {
                    Color.clear
                        .frame(width: 74, height: 74)
                        .clipShape(Circle())
                        .measure(target: .mapUserLocation)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                Color.clear
                    .frame(width: min(190, geo.size.width * 0.56), height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .measure(target: .mapMarkers)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Lifecycle

    private var renderedSpots: [Spot] {
        guard let focusedSpot = activeFocusRequest?.spot else {
            return mapVM.visibleSpots
        }
        return MapViewModel.mergeRetainingExisting(
            current: mapVM.visibleSpots,
            fresh: [focusedSpot]
        )
    }

    private func onAppear(geo _: GeometryProxy) {
        SpotLogger.log(MapViewLogs.mapAppeared, details: [
            "auth": authStatusLabel(permissionManager.locationStatus),
            "locationManagerAuth": authStatusLabel(locationManager.authorizationStatus),
            "hasLocationFix": locationManager.userLocation != nil
        ])
        MemoryDebugLogger.snapshot("map_appear")
        hasCenteredOnUser = false
        userHasMovedMap = false
        permissionManager.updatePermissionStatuses()

        if authVM.userId != nil {
            authVM.refreshUserFlags()
        }
        if applyPendingMapFocus() || activeFocusRequest != nil {
            return
        }
        performInitialFitIfNeeded()

        let isAuthorized = LocationPermissionPolicy.isAuthorized(permissionManager.locationStatus)
        if isAuthorized {
            SpotLogger.log(MapViewLogs.freshLocationRequested, details: [
                "hasCachedLocation": locationManager.userLocation != nil,
                "auth": authStatusLabel(permissionManager.locationStatus)
            ])
            locationManager.requestCurrentLocationForMapTab()
        }

        if let fix = locationManager.userLocation, isAuthorized {
            centerOnUser(coordinate: fix.coordinate, animated: false, source: "appear_cached")
            return
        }

        let fallback = MapDefaults.continentalUSRegion
        mapVM.loadForRegion(fallback)
        cameraIntent = .region(fallback, animated: false)
        SpotLogger.log(MapViewLogs.waitingForUserLocation, details: [
            "auth": authStatusLabel(permissionManager.locationStatus),
            "fallback": "continentalUS"
        ])
    }

    private var shouldShowRecenterControl: Bool {
        MapRecenterVisibility.shouldShow(
            status: permissionManager.locationStatus,
            hasLocation: locationManager.userLocation != nil
        )
    }

    private func onDisappear() {
        SpotLogger.log(MapViewLogs.mapDisappeared)
        MemoryDebugLogger.snapshot("map_disappear")
        locationManager.stopUpdatingLocation()
        hasCenteredOnUser = false
        userHasMovedMap = false
        lastCenteredCoordinate = nil
        selectedSpotId = nil
        activeFocusRequest = nil
        previewBottomReserved = 0
        clearSelectionToken += 1
        mapVM.clearVisibleSpots()
    }

    @discardableResult
    private func applyPendingMapFocus(expectedID: UUID? = nil) -> Bool {
        guard let request = mapFocusCoordinator.consumePending(id: expectedID) else {
            return false
        }
        activeFocusRequest = request
        selectedSpotId = request.spotID
        userHasMovedMap = true
        cameraIntent = .none
        let region = MapCameraRegion.neighborhood(
            center: request.coordinate,
            radiusMeters: Constants.MapDesign.initialNeighborhoodRadiusMeters
        )
        mapVM.loadForRegion(region)
        return true
    }

    private func handleLocationAuthorizationChange(
        from oldStatus: CLAuthorizationStatus,
        to newStatus: CLAuthorizationStatus
    ) {
        guard LocationPermissionPolicy.isAuthorized(newStatus) else { return }

        SpotLogger.log(MapViewLogs.freshLocationRequested, details: [
            "hasCachedLocation": locationManager.userLocation != nil,
            "auth": authStatusLabel(newStatus),
            "source": "permission_change",
            "previousAuth": authStatusLabel(oldStatus)
        ])

        userHasMovedMap = false
        hasCenteredOnUser = false
        locationManager.requestCurrentLocationForMapTab()

        if let cachedLocation = locationManager.userLocation {
            centerOnUser(
                coordinate: cachedLocation.coordinate,
                animated: true,
                source: "permission_change_cached"
            )
        }
    }

    private func onUserLocationReceived(_ location: CLLocation?) {
        guard let location else { return }
        guard selectedSpotId == nil else {
            SpotLogger.log(MapViewLogs.locationUpdateSkipped, details: [
                "reason": "drawerOpen"
            ])
            return
        }

        SpotLogger.log(MapViewLogs.freshLocationReceived, details: [
            "lat": location.coordinate.latitude,
            "lon": location.coordinate.longitude,
            "hasCenteredOnUser": hasCenteredOnUser,
            "userHasMovedMap": userHasMovedMap
        ])

        if !hasCenteredOnUser {
            centerOnUser(coordinate: location.coordinate, animated: true, source: "received_fix")
            return
        }

        guard !userHasMovedMap else {
            SpotLogger.log(MapViewLogs.locationUpdateSkipped, details: [
                "reason": "userMovedMap"
            ])
            return
        }

        if let lastCentered = lastCenteredCoordinate {
            let lastLocation = CLLocation(latitude: lastCentered.latitude,
                                         longitude: lastCentered.longitude)
            let distance = location.distance(from: lastLocation)
            if distance > 100 {
                SpotLogger.log(MapViewLogs.locationUpdateApplied, details: [
                    "distance": distance,
                    "fromLat": lastCentered.latitude,
                    "fromLon": lastCentered.longitude,
                    "toLat": location.coordinate.latitude,
                    "toLon": location.coordinate.longitude
                ])
                centerOnUser(coordinate: location.coordinate, animated: true, source: "location_changed")
            } else {
                SpotLogger.log(MapViewLogs.locationUpdateSkipped, details: [
                    "reason": "minorChange",
                    "distance": distance
                ])
            }
        }
    }

    private func centerOnUser(
        coordinate: CLLocationCoordinate2D,
        animated: Bool,
        source: String
    ) {
        hasCenteredOnUser = true
        lastCenteredCoordinate = coordinate
        let region = MapCameraRegion.neighborhood(
            center: coordinate,
            radiusMeters: Constants.MapDesign.initialNeighborhoodRadiusMeters
        )
        let intent = SharedSpotMapCameraIntent.region(region, animated: animated)
        let intentUnchanged = cameraIntent == intent
        cameraIntent = intent
        clearCameraIntentAfterApply(intent)
        mapVM.loadForRegion(region)
        SpotLogger.log(MapViewLogs.initialFitApplied, details: [
            "source": source,
            "lat": coordinate.latitude,
            "lon": coordinate.longitude,
            "animated": animated,
            "intentUnchanged": intentUnchanged
        ])
    }

    private func clearCameraIntentAfterApply(_ applied: SharedSpotMapCameraIntent) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard cameraIntent == applied else { return }
            SpotLogger.log(MapViewLogs.staleCameraIntentCleared)
            cameraIntent = .none
        }
    }

    private var filterPillBinding: Binding<SpotMapFilterState>? {
        guard MapFilterGate.isAvailable(isPro: authVM.isPro) else { return nil }
        return Binding(
            get: { filterState },
            set: { newValue in
                let opening = !filterState.isActive && newValue.isActive
                if opening {
                    SpotLogger.log(MapFilterLogs.filterSheetOpened)
                }
                filterState = newValue
            }
        )
    }

    private var userMarker: SpotUserLocationAnnotation? {
        guard let loc = locationManager.userLocation else { return nil }
        return SpotUserLocationAnnotation(
            coordinate: loc.coordinate,
            profileImageURL: authVM.currentUserProfileImageURL,
            username: authVM.currentUserUsername,
            kind: authVM.isPro ? .pro : .regular
        )
    }

    private func handleMapRegionChanged(_ region: MKCoordinateRegion) {
        lastRegionFromMap = region
        let isProgrammatic = cameraIntent != .none
        if !isProgrammatic && hasCenteredOnUser {
            userHasMovedMap = true
        }
        cameraIntent = .none
        mapVM.loadForRegion(region)
    }

    private func recenterOnUser() {
        permissionManager.updatePermissionStatuses()
        userHasMovedMap = false
        MapAnalytics.recenterTapped()

        let outcome: String
        switch permissionManager.locationStatus {
        case .notDetermined:
            showLocationPrePrompt = true
            outcome = "showedPrePrompt"
        case .denied, .restricted:
            if let loc = locationManager.userLocation {
                selectedSpotId = nil
                previewBottomReserved = 0
                centerOnUser(coordinate: loc.coordinate, animated: true, source: "recenter_button")
                outcome = "centeredOnCachedFix"
            } else {
                SpotLogger.log(MapViewLogs.userLocationUnavailable)
                outcome = "deniedWithNoFix"
            }
        case .authorizedAlways, .authorizedWhenInUse:
            if let loc = locationManager.userLocation {
                selectedSpotId = nil
                previewBottomReserved = 0
                centerOnUser(coordinate: loc.coordinate, animated: true, source: "recenter_button")
                locationManager.requestCurrentLocationForMapTab()
                outcome = "centered"
            } else {
                hasCenteredOnUser = false
                lastCenteredCoordinate = nil
                locationManager.requestCurrentLocationForMapTab()
                outcome = "awaitingFirstFix"
            }
        @unknown default:
            SpotLogger.log(MapViewLogs.userLocationUnavailable)
            outcome = "unknownAuth"
        }

        SpotLogger.log(MapViewLogs.recenterTapped, details: [
            "auth": authStatusLabel(permissionManager.locationStatus),
            "locationManagerAuth": authStatusLabel(locationManager.authorizationStatus),
            "hasLocationFix": locationManager.userLocation != nil,
            "outcome": outcome
        ])
    }

    private func performInitialFitIfNeeded() {
        guard !hasPerformedInitialFit else { return }
        hasPerformedInitialFit = true
        SpotLogger.log(MapViewLogs.initialFitApplied, details: [
            "hasUserLocation": locationManager.userLocation != nil,
            "source": "appear_marker"
        ])
    }

    private func syncMapSelectionWithActiveFilter(_ filter: SpotMapFilterState) {
        if activeFocusRequest?.spotID == selectedSpotId {
            return
        }
        guard let id = selectedSpotId,
              let sel = mapVM.visibleSpots.first(where: { $0.id == id }) else { return }
        guard filter.isActive else { return }
        let stillMatches = SpotMarkerStyleResolver.matches(
            sel,
            filter: filter,
            savedSpotIds: Set(authVM.bookmarkedSpots),
            likedSpotIds: Set(authVM.likedSpots),
            followedUserIds: []
        )
        if !stillMatches {
            selectedSpotId = nil
            previewBottomReserved = 0
            clearSelectionToken += 1
        }
    }

    private func authStatusLabel(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
}

#Preview("MapView – discovery") {
    MapView(spots: [
        Spot(id: "1", userId: "u1", username: "eddie",
             imageURL: "https://picsum.photos/seed/3/800/600", vibeTag: "Park",
             latitude: 40.7128, longitude: -74.0060,
             locationName: "NYC", createdAt: Date())
    ])
    .environmentObject(AuthViewModel())
    .environmentObject(PermissionManager.shared)
}
