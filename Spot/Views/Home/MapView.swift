//
//  MapView.swift
//  Spot
//
//  Discovery map. Redesigned to:
//   * use the shared `SharedSpotMap` host (single MKMapView, reused
//     annotations, light mode, no POIs, no MapKit numeric clusters),
//   * render a branded user-location avatar marker (green ring / gold
//     ring for Pro) instead of the default blue dot,
//   * show a stable soft-cluster + individual-pin density model,
//   * fix the IMG_9741 panel overflow bug via `MapSpotPreviewCard` +
//     `MapPanelHeight.clamp`,
//   * fetch viewport spots after pan/zoom settles,
//   * surface a Pro-only filter pill row (hidden for non-Pro), and
//   * emit structured map logs for screen lifecycle, panel state,
//     density transitions, recenter taps, and (debug) memory snapshots.
//

import SwiftUI
import MapKit
import CoreLocation

@MainActor
struct MapView: View {

    // MARK: - State

    @StateObject private var mapVM = MapViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var permissionManager: PermissionManager

    /// True while the contextual Location pre-prompt sheet is presented.
    /// Shown when the user explicitly asks to use their location (recenter
    /// button) or when the first-run map tour reaches "Start from where
    /// you are". Not on tab open — permission education tracks user intent.
    @State private var showLocationPrePrompt: Bool = false

    @State private var selectedSpot: Spot?
    @State private var selectedSpotCoordinate: CLLocationCoordinate2D?
    @State private var cameraIntent: SharedSpotMapCameraIntent = .none
    @State private var hasPerformedInitialFit: Bool = false
    /// `true` once the camera has been programmatically centered on the
    /// viewer's real location. Subsequent location updates do not re-zoom
    /// (the user can manually pan or tap recenter) — but if we never got a
    /// fix at appear time, the first fix from `.onReceive` triggers it.
    @State private var hasCenteredOnUser: Bool = false
    @State private var lastRegionFromMap: MKCoordinateRegion?
    /// Coordinate we last centered on, used to detect if a fresh location
    /// update is significantly different and should trigger a re-center.
    @State private var lastCenteredCoordinate: CLLocationCoordinate2D?
    /// Track if user has manually interacted with the map. If true, we
    /// won't automatically re-center on fresh location updates.
    @State private var userHasMovedMap: Bool = false

    @State private var filterState: SpotMapFilterState = .empty
    @State private var showVibePicker: Bool = false

    /// Ignore user-move dismissal until marker-focus / programmatic camera finishes.
    @State private var programmaticCameraSuppressUntil: Date?
    /// Last region snapshot while the drawer is open (updated during suppression; compared after).
    @State private var drawerRegionBaseline: MKCoordinateRegion?
    /// Cancels stale delayed spot-switch updates when markers are tapped quickly.
    @State private var selectionSequence: Int = 0
    /// Discovery drawer: short peek vs raised sheet (full-width, rounded top).
    @State private var mapDrawerDetent: MapSpotDrawerDetent = .peek
    /// Bottom Y of the Pro filter pill row in `mapCanvas` space (`nil` when hidden or not yet laid out).
    @State private var mapFilterPillsMaxY: CGFloat?
    /// Viewport to restore when closing the drawer (from first pin tap in a chain).
    @State private var regionBeforeSpotSelection: MKCoordinateRegion?

    @Environment(\.verticalSizeClass) private var vSize

    init(spots _: [Spot] = []) {}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    SharedSpotMap(
                        spots: mapVM.visibleSpots,
                        selectedSpotId: selectedSpot?.id,
                        filter: filterState,
                        savedSpotIds: Set(authVM.bookmarkedSpots),
                        likedSpotIds: Set(authVM.likedSpots),
                        followedUserIds: [],
                        allowSoftClusters: false,
                        userMarker: userMarker,
                        suppressDefaultUserDot: true,
                        cameraIntent: cameraIntent,
                        onSelect: { spot, coord, regionAtTap in
                            select(
                                spot,
                                coord,
                                regionAtTap: regionAtTap,
                                geo: geo
                            )
                        },
                        onDeselect: { handleAnnotationDeselectForEmptyMapTap() },
                        onRegionChanged: { region in
                            handleMapRegionChanged(region)
                        }
                    )
                    // The map is the canvas for this tab. Let it continue behind the
                    // status bar as well as the home indicator so no cream strip cuts
                    // the map off at the top; MapControlsOverlay applies its own safe
                    // area spacing for interactive controls.
                    .ignoresSafeArea()
                    .accessibilityIdentifier("map.mapView")
                    .overlay {
                        mapOnboardingTargets
                    }

                    if let spot = selectedSpot {
                        mapDrawerOverlay(
                            spot: spot,
                            geo: geo
                        )
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .opacity)
                        )
                        .zIndex(5)
                    }

                    MapControlsOverlay(
                        filterState: filterPillBinding,
                        availableVibeTags: Constants.VibeTags.defaultTags,
                        onOpenVibePicker: { showVibePicker = true },
                        canRecenter: shouldShowRecenterControl,
                        onRecenter: recenterOnUser,
                        bottomReservedHeight: selectedSpot == nil
                            ? 0
                            : mapDrawerResolvedHeight(in: geo)
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(true)
                    .zIndex(10)
                }
                .coordinateSpace(name: "mapCanvas")
                .onPreferenceChange(MapFilterPillRowBottomPreferenceKey.self) { value in
                    mapFilterPillsMaxY = value
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
            guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 1 else { return }
            showVibePicker = false
            if selectedSpot != nil {
                dismissSelectedSpot(reason: .tabReselected, animated: true)
            }
        }
    }

    // MARK: - Bottom drawer (root-level overlay, full width)

    @ViewBuilder
    private func mapDrawerOverlay(spot: Spot, geo: GeometryProxy) -> some View {
        let height = mapDrawerResolvedHeight(in: geo)
        MapSpotPreviewCard(
            spot: spot,
            source: "Map",
            onClose: { closePanel() },
            drawerDetent: $mapDrawerDetent
        )
        .id(spot.id ?? spot.safeId)
        .measure(target: .mapMarkerPreview)
        .frame(width: geo.size.width)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: height)
        .clipped()
        .animation(
            .spring(
                response: Constants.MapDesign.selectSpringResponse,
                dampingFraction: Constants.MapDesign.selectSpringDamping
            ),
            value: selectedSpot?.id
        )
        .animation(
            .spring(
                response: Constants.MapDesign.selectSpringResponse,
                dampingFraction: Constants.MapDesign.selectSpringDamping
            ),
            value: mapDrawerDetent
        )
    }

    /// Peek / expanded heights, capped so the drawer stops ~`mapDrawerGapBelowFilterPills` below the filter pills.
    private func mapDrawerResolvedHeight(in geo: GeometryProxy) -> CGFloat {
        let safe = geo.safeAreaInsets.bottom
        let ceiling = drawerMaxHeightBelowFilterPills(in: geo)
        let requested: CGFloat
        switch mapDrawerDetent {
        case .peek:
            requested = openPanelHeight(in: geo.size, safe: safe).height
        case .expanded:
            requested = expandedMapDrawerHeight(in: geo.size, bottomSafeArea: safe)
        }
        return MapDrawerLayoutPolicy.resolvedHeight(
            requested: requested,
            ceiling: ceiling,
            minHeight: Constants.MapDesign.panelMinHeight
        )
    }

    /// Max drawer height from bottom padding up to `gap` below the measured filter row (or a safe fallback when non‑Pro).
    private func drawerMaxHeightBelowFilterPills(in geo: GeometryProxy) -> CGFloat {
        MapDrawerLayoutPolicy.maxHeightBelowFilterPills(
            screenHeight: geo.size.height,
            bottomPadding: max(geo.safeAreaInsets.bottom, 8),
            pillsBottomY: filterPillsBottomY(in: geo),
            gap: Constants.MapDesign.mapDrawerGapBelowFilterPills
        )
    }

    private func filterPillsBottomY(in geo: GeometryProxy) -> CGFloat {
        MapDrawerLayoutPolicy.filterPillsBottomY(
            measuredMaxY: mapFilterPillsMaxY,
            safeAreaTop: geo.safeAreaInsets.top
        )
    }

    /// Peek height used for pin camera lift — matches capped peek drawer.
    private func peekPanelHeightForCameraLift(in geo: GeometryProxy) -> CGFloat {
        let safe = geo.safeAreaInsets.bottom
        let requested = openPanelHeight(in: geo.size, safe: safe).height
        let ceiling = drawerMaxHeightBelowFilterPills(in: geo)
        return MapDrawerLayoutPolicy.resolvedHeight(
            requested: requested,
            ceiling: ceiling,
            minHeight: Constants.MapDesign.panelMinHeight
        )
    }

    private func expandedMapDrawerHeight(in size: CGSize, bottomSafeArea: CGFloat) -> CGFloat {
        MapDrawerLayoutPolicy.expandedHeight(
            screenHeight: size.height,
            bottomSafeArea: bottomSafeArea,
            maxScreenFraction: Constants.MapDesign.panelMaxScreenFraction,
            minHeight: Constants.MapDesign.panelMinHeight
        )
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

    /// Computes the safe panel height + emits a `panelHeightClamped` log if
    /// the requested height was reduced by the safe-area / max-fraction
    /// clamp. This is the IMG_9741 fix point.
    private func openPanelHeight(in size: CGSize, safe: CGFloat) -> (height: CGFloat, wasClamped: Bool) {
        // Keep more map visible while still showing enough of the spot card.
        let base: CGFloat = (vSize == .compact) ? size.height * 0.30 : size.height * 0.36
        let clamp = MapPanelHeight.clamp(
            requested: base,
            availableHeight: size.height,
            bottomSafeArea: safe
        )
        if clamp.wasClamped {
            SpotLogger.log(MapViewLogs.panelHeightClamped, details: [
                "requested": Int(base),
                "applied": Int(clamp.height),
                "screen": Int(size.height),
                "bottomSafe": Int(safe)
            ])
        }
        return clamp
    }

    // MARK: - Lifecycle hooks

    private func onAppear(geo: GeometryProxy) {
        SpotLogger.log(MapViewLogs.mapAppeared, details: [
            "auth": authStatusLabel(permissionManager.locationStatus),
            "locationManagerAuth": authStatusLabel(locationManager.authorizationStatus),
            "hasLocationFix": locationManager.userLocation != nil
        ])
        MemoryDebugLogger.snapshot("map_appear")
        // Re-arm the one-shot auto-center every time the map tab appears.
        hasCenteredOnUser = false
        userHasMovedMap = false
        permissionManager.updatePermissionStatuses()
        
        if authVM.userId != nil {
            authVM.refreshUserFlags()
        }
        performInitialFitIfNeeded()

        // Always request a fresh location when authorized, even if we have
        // a cached one. This ensures the map shows the user's current
        // location, not where they were during onboarding or last session.
        let isAuthorized = LocationPermissionPolicy.isAuthorized(permissionManager.locationStatus)
        if isAuthorized {
            SpotLogger.log(MapViewLogs.freshLocationRequested, details: [
                "hasCachedLocation": locationManager.userLocation != nil,
                "auth": authStatusLabel(permissionManager.locationStatus)
            ])
            locationManager.requestCurrentLocationForMapTab()
        }

        // Best path: we already have a real or cached location fix →
        // jump straight to it for immediate feedback. A fresh location
        // update will arrive shortly via `onUserLocationReceived` if the
        // user has moved significantly.
        if let fix = locationManager.userLocation, isAuthorized {
            centerOnUser(coordinate: fix.coordinate, animated: false, source: "appear_cached")
            return
        }

        // Apple App Review (Guideline 5.1.5): the map MUST open and remain
        // browsable when location is denied/restricted/disabled or simply
        // unavailable. Never sit in `cameraIntent = .none` waiting for a fix
        // that may never come — paint the continental-US overview now so the
        // user can pan, zoom, and search immediately. If a real fix arrives
        // later, `onUserLocationReceived` re-centers (one-shot guarded by
        // `hasCenteredOnUser`).
        let fallback = MapDefaults.continentalUSRegion
        mapVM.loadForRegion(fallback)
        cameraIntent = .region(fallback, animated: false)
        SpotLogger.log(MapViewLogs.waitingForUserLocation, details: [
            "auth": authStatusLabel(permissionManager.locationStatus),
            "fallback": "continentalUS"
        ])
    }

    /// Recenter is offered whenever location could apply: user already has
    /// a fix, permission is still undecided (tap → pre-prompt), or we are
    /// authorized but still waiting on CoreLocation. Hidden when access is
    /// denied/restricted and we have no cached coordinate to recenter on.
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
        mapFilterPillsMaxY = nil
        if selectedSpot != nil {
            dismissSelectedSpot(reason: .tabLeft, animated: false)
        }
        mapVM.clearVisibleSpots()
    }

    /// Permission can change while the map remains mounted (native prompt)
    /// or while the app is in Settings. `onAppear` will not run in either
    /// case, so react to PermissionManager's system refresh directly.
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

        // Give immediate feedback from the persisted last-known-good fix.
        // The subsequent CoreLocation callback replaces it with a fresh fix.
        if let cachedLocation = locationManager.userLocation {
            centerOnUser(
                coordinate: cachedLocation.coordinate,
                animated: true,
                source: "permission_change_cached"
            )
        }
    }

    /// Fired for the initial published value AND every subsequent fix.
    /// `.onChange(of:)` doesn't fire for the initial value so it would
    /// silently miss the case where `LocationManager` already had a fix
    /// from earlier in the app session.
    private func onUserLocationReceived(_ location: CLLocation?) {
        guard let location else { return }
        guard selectedSpot == nil else {
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
        
        // If we haven't centered yet, do the initial center
        if !hasCenteredOnUser {
            centerOnUser(coordinate: location.coordinate, animated: true, source: "received_fix")
            return
        }
        
        // If user has manually moved the map, don't fight them with auto-updates
        guard !userHasMovedMap else {
            SpotLogger.log(MapViewLogs.locationUpdateSkipped, details: [
                "reason": "userMovedMap"
            ])
            return
        }
        
        // Check if the new location is significantly different from where we centered
        if let lastCentered = lastCenteredCoordinate {
            let lastLocation = CLLocation(latitude: lastCentered.latitude,
                                         longitude: lastCentered.longitude)
            let distance = location.distance(from: lastLocation)
            
            // Only re-center if the user has moved more than 100 meters
            // This prevents jittery updates from GPS drift while still
            // catching meaningful location changes
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

    /// Center the discovery camera on `coordinate` and trigger a viewport
    /// fetch in the same beat. Sets `hasCenteredOnUser` so we don't keep
    /// fighting the user once they pan around. Tracks the centered coordinate
    /// so we can detect significant location changes later.
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

    /// Camera intents are one-shot commands, but `SharedSpotMap` ignores an
    /// intent equal to the last one it applied and MapKit swallows the settle
    /// callback for programmatic moves — so an uncleared intent turns a repeat
    /// recenter into a no-op. Reset it once the move has had time to land.
    private func clearCameraIntentAfterApply(_ applied: SharedSpotMapCameraIntent) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard cameraIntent == applied else { return }
            SpotLogger.log(MapViewLogs.staleCameraIntentCleared)
            cameraIntent = .none
        }
    }

    // MARK: - Filter binding (Pro gating)

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

    // MARK: - User marker

    private var userMarker: SpotUserLocationAnnotation? {
        guard let loc = locationManager.userLocation else { return nil }
        return SpotUserLocationAnnotation(
            coordinate: loc.coordinate,
            profileImageURL: authVM.currentUserProfileImageURL,
            username: authVM.currentUserUsername,
            kind: authVM.isPro ? .pro : .regular
        )
    }

    // MARK: - Actions

    private var isProgrammaticCameraSuppressActive: Bool {
        guard let until = programmaticCameraSuppressUntil else { return false }
        return Date() < until
    }

    private func scheduleProgrammaticCameraSuppression() {
        programmaticCameraSuppressUntil = Date().addingTimeInterval(
            MapDiscoveryDrawerPolicy.programmaticCameraSuppressionSeconds
        )
    }

    private func select(
        _ spot: Spot,
        _ coordinate: CLLocationCoordinate2D,
        regionAtTap: MKCoordinateRegion,
        geo: GeometryProxy
    ) {
        /// Snapshot restore target only when opening from “no drawer” — keeps the original viewport through pin switches.
        let hadDrawerOpen = selectedSpot != nil
        let newId = spot.id
        let oldId = selectedSpot?.id
        let isSwitch = oldId != nil && newId != nil && oldId != newId

        if isSwitch {
            SpotLogger.log(MapViewLogs.mapSpotSwitchAnimated, details: [
                "fromSpotId": oldId ?? "nil",
                "toSpotId": newId ?? "nil"
            ])
            selectionSequence += 1
            let seq = selectionSequence
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedSpot = nil
                selectedSpotCoordinate = nil
                drawerRegionBaseline = nil
                mapDrawerDetent = .peek
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 160_000_000)
                guard seq == selectionSequence else { return }
                applyMarkerSelection(
                    spot,
                    coordinate,
                    regionAtTap: regionAtTap,
                    geo: geo,
                    captureRestoreRegion: !hadDrawerOpen
                )
            }
        } else {
            selectionSequence += 1
            applyMarkerSelection(
                spot,
                coordinate,
                regionAtTap: regionAtTap,
                geo: geo,
                captureRestoreRegion: !hadDrawerOpen
            )
        }
    }

    private func applyMarkerSelection(
        _ spot: Spot,
        _ coordinate: CLLocationCoordinate2D,
        regionAtTap: MKCoordinateRegion,
        geo: GeometryProxy,
        captureRestoreRegion: Bool
    ) {
        if captureRestoreRegion {
            regionBeforeSpotSelection = regionAtTap
        }
        withAnimation(
            .spring(
                response: Constants.MapDesign.selectSpringResponse,
                dampingFraction: Constants.MapDesign.selectSpringDamping
            )
        ) {
            selectedSpot = spot
            selectedSpotCoordinate = coordinate
            mapDrawerDetent = .peek
        }
        drawerRegionBaseline = nil
        scheduleProgrammaticCameraSuppression()

        SpotLogger.log(MapViewLogs.homeSheetOpen, details: ["spotId": spot.id ?? "nil"])
        FeedEventService.record(.mapPinTap, spotId: spot.id)
        FeedEventService.record(.detailOpen, spotId: spot.id, metadata: ["surface": "map_panel"])
        let panelHeight = peekPanelHeightForCameraLift(in: geo)
        let dynamicLift = max(
            Constants.MapDesign.selectedPinCameraLift,
            panelHeight * 0.42
        )
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        cameraIntent = .focus(
            coordinate: coordinate,
            span: span,
            liftPoints: dynamicLift,
            animated: true
        )
    }

    private func handleMapRegionChanged(_ region: MKCoordinateRegion) {
        lastRegionFromMap = region
        
        // Track if this region change was user-initiated (not programmatic).
        // If we're not in a programmatic camera suppression window and the
        // camera intent is none, this is a user pan/zoom.
        let isProgrammatic = isProgrammaticCameraSuppressActive || cameraIntent != .none
        if !isProgrammatic && hasCenteredOnUser {
            userHasMovedMap = true
        }
        
        cameraIntent = .none
        mapVM.loadForRegion(region)

        guard selectedSpot != nil else {
            drawerRegionBaseline = nil
            return
        }

        if isProgrammaticCameraSuppressActive {
            drawerRegionBaseline = region
            return
        }

        if let base = drawerRegionBaseline {
            if MapDiscoveryDrawerPolicy.regionsMeaningfullyDiffer(base, region) {
                dismissSelectedSpot(reason: .mapMoved, animated: true)
            }
        } else {
            drawerRegionBaseline = region
        }
    }

    private func handleAnnotationDeselectForEmptyMapTap() {
        let priorId = selectedSpot?.id
        guard let priorId else { return }
        Task { @MainActor in
            await Task.yield()
            guard selectedSpot?.id == priorId else { return }
            dismissSelectedSpot(reason: .emptyMapTap, animated: true)
        }
    }

    private func dismissSelectedSpot(
        reason: MapDrawerDismissReason,
        animated: Bool = true
    ) {
        guard let spot = selectedSpot else { return }
        let spotId = spot.id ?? spot.safeId
        SpotLogger.log(MapViewLogs.mapDrawerDismissed, details: [
            "reason": reason.rawValue,
            "spotId": spotId
        ])
        SpotLogger.log(MapViewLogs.homeSheetClose, details: [
            "spotId": spotId,
            "reason": reason.rawValue
        ])
        let restoreRegion = regionBeforeSpotSelection
        let restoreViewport = shouldRestoreViewportAfterDismiss(reason: reason)
        let apply = {
            self.selectedSpot = nil
            self.selectedSpotCoordinate = nil
            self.drawerRegionBaseline = nil
            self.programmaticCameraSuppressUntil = nil
            self.mapDrawerDetent = .peek
            self.regionBeforeSpotSelection = nil
            if restoreViewport, let region = restoreRegion {
                self.cameraIntent = .region(region, animated: true)
                self.scheduleProgrammaticCameraSuppression()
            } else {
                self.cameraIntent = .none
            }
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.18), apply)
        } else {
            apply()
        }
    }

    /// After dismiss, zoom back to the pre-spot viewport unless the user already moved the map (e.g. pan dismiss).
    private func shouldRestoreViewportAfterDismiss(reason: MapDrawerDismissReason) -> Bool {
        MapDrawerDismissRestore.shouldRestoreViewport(after: reason)
    }

    private func closePanel() {
        dismissSelectedSpot(reason: .closeButton, animated: true)
    }

    private func recenterOnUser() {
        permissionManager.updatePermissionStatuses()

        // Reset the "user moved map" flag since recenter is an explicit
        // action to re-enable location tracking
        userHasMovedMap = false

        let outcome: String
        switch permissionManager.locationStatus {
        case .notDetermined:
            showLocationPrePrompt = true
            outcome = "showedPrePrompt"
        case .denied, .restricted:
            if let loc = locationManager.userLocation {
                if selectedSpot != nil {
                    dismissSelectedSpot(reason: .mapMoved, animated: false)
                }
                centerOnUser(coordinate: loc.coordinate, animated: true, source: "recenter_button")
                outcome = "centeredOnCachedFix"
            } else {
                SpotLogger.log(MapViewLogs.userLocationUnavailable)
                outcome = "deniedWithNoFix"
            }
        case .authorizedAlways, .authorizedWhenInUse:
            if let loc = locationManager.userLocation {
                if selectedSpot != nil {
                    dismissSelectedSpot(reason: .mapMoved, animated: false)
                }
                centerOnUser(coordinate: loc.coordinate, animated: true, source: "recenter_button")
                // Request fresh location in case the user has moved
                locationManager.requestCurrentLocationForMapTab()
                outcome = "centered"
            } else {
                // No fix yet. Re-arm the one-shot auto-center so whichever
                // fix CoreLocation delivers next moves the camera, instead
                // of the tap silently doing nothing.
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

    /// Close the preview sheet if the active filter no longer includes the
    /// selected spot (pins are removed from the map, not dimmed).
    private func syncMapSelectionWithActiveFilter(_ filter: SpotMapFilterState) {
        guard let sel = selectedSpot else { return }
        guard filter.isActive else { return }
        let stillMatches = SpotMarkerStyleResolver.matches(
            sel,
            filter: filter,
            savedSpotIds: Set(authVM.bookmarkedSpots),
            likedSpotIds: Set(authVM.likedSpots),
            followedUserIds: []
        )
        if !stillMatches {
            dismissSelectedSpot(reason: .selectedSpotNoLongerVisible, animated: true)
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

// MARK: - Preview

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
