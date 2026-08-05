//
//  SharedSpotMap.swift
//  Spot
//
//  The single, reusable `MKMapView` host that powers both the discovery
//  map and the profile map. Replaces the two prior `UIViewRepresentable`
//  stacks (`ClusteredSpotMap` + `InnerProfileSpotMap`) so the new marker
//  visual language and lifecycle/memory rules live in one place.
//
//  Memory rules enforced here:
//   * Force light mode.
//   * No POIs, no traffic, flat elevation.
//   * Reuse `SpotAnnotationView`, `UserLocationAnnotationView`,
//     `SoftClusterAnnotationView` via stable identifiers.
//   * Diff annotations by spot id (add new, remove only ids no longer in
//     the displayed set, never `removeAnnotations` + `addAnnotations`
//     wholesale).
//   * Never call `showAnnotations` reactively — camera moves are explicit
//     and triggered by `cameraIntent`.
//   * Cluster expansion happens through `SpotSoftClusterAnnotation` only;
//     we set `clusteringIdentifier = nil` so MapKit's numeric cluster
//     bubble never appears.
//   * `dismantleUIView` releases delegate, annotations, overlays.
//

import SwiftUI
import MapKit

// MARK: - Camera intent

/// Explicit, intent-based camera commands. The wrapping view sends these
/// to the map; the map only moves the camera in response. This avoids
/// the previous `showAnnotations`-as-default fight that produced odd
/// shifts when the spot card opened.
enum SharedSpotMapCameraIntent: Equatable {
    case none
    case region(MKCoordinateRegion, animated: Bool)
    case fitAll(animated: Bool)
    case focus(coordinate: CLLocationCoordinate2D,
               span: MKCoordinateSpan,
               liftPoints: CGFloat,
               animated: Bool)

    static func == (lhs: SharedSpotMapCameraIntent, rhs: SharedSpotMapCameraIntent) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case let (.region(a, x), .region(b, y)): return regionsEqual(a, b) && x == y
        case let (.fitAll(x), .fitAll(y)): return x == y
        case let (.focus(c1, s1, l1, a1), .focus(c2, s2, l2, a2)):
            return c1.latitude == c2.latitude && c1.longitude == c2.longitude
                && s1.latitudeDelta == s2.latitudeDelta && s1.longitudeDelta == s2.longitudeDelta
                && l1 == l2 && a1 == a2
        default: return false
        }
    }

    private static func regionsEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        a.center.latitude == b.center.latitude
            && a.center.longitude == b.center.longitude
            && a.span.latitudeDelta == b.span.latitudeDelta
            && a.span.longitudeDelta == b.span.longitudeDelta
    }
}

// MARK: - SharedSpotMap

struct SharedSpotMap: UIViewRepresentable {

    // Data
    let spots: [Spot]
    let selectedSpotId: String?
    let filter: SpotMapFilterState
    let savedSpotIds: Set<String>
    let likedSpotIds: Set<String>
    let followedUserIds: Set<String>
    /// Discovery map can disable soft clusters to draw every visible spot
    /// row as an individual annotation.
    let allowSoftClusters: Bool

    // User-location marker (discovery only — pass `userMarker = nil` on profile).
    let userMarker: SpotUserLocationAnnotation?
    /// When true, even if `userMarker == nil`, MapKit's default blue dot
    /// is suppressed. Profile map uses this.
    let suppressDefaultUserDot: Bool

    // Intent
    let cameraIntent: SharedSpotMapCameraIntent

    /// `MKCoordinateRegion` is `mapView.region` immediately before pin-focus camera work — used to restore on dismiss.
    let onSelect: (Spot, CLLocationCoordinate2D, MKCoordinateRegion) -> Void
    let onDeselect: () -> Void
    let onRegionChanged: (MKCoordinateRegion) -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsTraffic = false
        map.showsCompass = false
        map.showsScale = false
        map.showsBuildings = false
        // Hide MapKit's default blue dot if we're rendering our own marker
        // OR if the host explicitly suppresses it (profile map).
        map.showsUserLocation = !(suppressDefaultUserDot || userMarker != nil)

        if #available(iOS 13.0, *) {
            map.overrideUserInterfaceStyle = .light
            let cfg = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            cfg.pointOfInterestFilter = .excludingAll
            map.preferredConfiguration = cfg
        }

        map.register(SpotAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: SpotAnnotationView.reuseIdentifier)
        map.register(SoftClusterAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: SoftClusterAnnotationView.reuseIdentifier)
        map.register(UserLocationAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: UserLocationAnnotationView.reuseIdentifier)

        context.coordinator.attach(map: map)
        SpotLogger.log(MapMarkerLogs.markersAdded, details: ["initial": true])
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyData(map: map, spots: spots, selectedSpotId: selectedSpotId)
        context.coordinator.applyUserMarker(map: map, marker: userMarker, suppressDefault: suppressDefaultUserDot)
        context.coordinator.applyCameraIntent(map: map, intent: cameraIntent)
    }

    func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        coordinator.detach(map: map)
        map.delegate = nil
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)
        map.showsUserLocation = false
        map.isHidden = true
        map.alpha = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SharedSpotMap
        private var renderedAnnotations: [String: SpotMapAnnotation] = [:]
        private var renderedClusters: [String: SpotSoftClusterAnnotation] = [:]
        private var renderedUserAnnotation: SpotUserLocationAnnotation?
        private var lastAppliedDensity: MapDensityMode?
        private var lastAppliedCameraIntent: SharedSpotMapCameraIntent = .none
        private var regionDebounceTask: Task<Void, Never>?
        private let overlapResolver = MapOverlapResolver()
        private var animatedSpotIds: Set<String> = []
        private var ignoreNextRegionChange: Bool = false
        /// Set after the SwiftUI parent applies a non-`.none` camera intent.
        /// Until then, `regionDidChange` often reports MapKit's huge default
        /// region while the view has zero bounds — we must not forward that
        /// to `onRegionChanged` or the viewport fetch will zoom the whole USA.
        private var didApplyExplicitCameraFromParent = false

        init(_ parent: SharedSpotMap) {
            self.parent = parent
        }

        func attach(map _: MKMapView) {
            // Reserved for future — keeps API symmetric with detach.
        }

        func detach(map _: MKMapView) {
            regionDebounceTask?.cancel()
            renderedAnnotations.removeAll()
            renderedClusters.removeAll()
            renderedUserAnnotation = nil
            animatedSpotIds.removeAll()
            didApplyExplicitCameraFromParent = false
        }

        // MARK: - Data application

        func applyData(map: MKMapView, spots: [Spot], selectedSpotId: String?) {
            let modelSpots = SpotMapDisplayFilter.spotsToDisplay(
                spots,
                filter: parent.filter,
                savedSpotIds: parent.savedSpotIds,
                likedSpotIds: parent.likedSpotIds,
                followedUserIds: parent.followedUserIds
            )

            let rawDensity = MapDensityMode.mode(for: map.region)
            let density: MapDensityMode = parent.allowSoftClusters ? rawDensity : .individualPinsWithSoftOverlap
            if density != lastAppliedDensity {
                lastAppliedDensity = density
                SpotLogger.log(MapViewLogs.densityModeChanged, details: ["mode": density.rawValue])
            }

            let displayed: [(spot: Spot, coordinate: CLLocationCoordinate2D, isCluster: Bool, clusterMemberIds: [String])]
            switch density {
            case .individualPins:
                displayed = parent
                    .resolved(spots: modelSpots, withOverlap: false)
                    .map { ($0.spot, $0.coordinate, false, []) }
            case .individualPinsWithSoftOverlap:
                let stats = overlapResolver.bucketStats(modelSpots)
                if stats.multiBuckets > 0 {
                    SpotLogger.log(MapMarkerLogs.overlapBucketResolved, details: [
                        "totalBuckets": stats.totalBuckets,
                        "multiBuckets": stats.multiBuckets,
                        "maxMembers": stats.maxMembers
                    ])
                }
                displayed = parent
                    .resolved(spots: modelSpots, withOverlap: true)
                    .map { ($0.spot, $0.coordinate, false, []) }
            case .softClusters:
                displayed = parent.softClusters(for: modelSpots)
            }

            // Diff with previously rendered set.
            var nextAnnotationKeys = Set<String>()
            var nextClusterKeys = Set<String>()
            var toAdd: [MKAnnotation] = []
            var toRemove: [MKAnnotation] = []

            for entry in displayed {
                if entry.isCluster {
                    let key = "cluster:\(entry.coordinate.latitude),\(entry.coordinate.longitude),\(entry.clusterMemberIds.count)"
                    nextClusterKeys.insert(key)
                    if let existing = renderedClusters[key] {
                        if existing.coordinate.latitude != entry.coordinate.latitude
                            || existing.coordinate.longitude != entry.coordinate.longitude {
                            existing.coordinate = entry.coordinate
                        }
                    } else {
                        let cluster = SpotSoftClusterAnnotation(
                            coordinate: entry.coordinate,
                            memberCount: entry.clusterMemberIds.count,
                            memberSpotIds: entry.clusterMemberIds
                        )
                        renderedClusters[key] = cluster
                        toAdd.append(cluster)
                    }
                } else {
                    guard let id = entry.spot.id else { continue }
                    nextAnnotationKeys.insert(id)
                    let resolvedState = SpotMarkerStyleResolver.state(
                        for: entry.spot,
                        selectedSpotId: selectedSpotId,
                        filter: parent.filter,
                        savedSpotIds: parent.savedSpotIds,
                        likedSpotIds: parent.likedSpotIds,
                        followedUserIds: parent.followedUserIds
                    )
                    if let existing = renderedAnnotations[id] {
                        if existing.coordinate.latitude != entry.coordinate.latitude
                            || existing.coordinate.longitude != entry.coordinate.longitude {
                            existing.coordinate = entry.coordinate
                        }
                        existing.visualState = resolvedState
                        if let view = map.view(for: existing) as? SpotAnnotationView {
                            view.apply(state: resolvedState, animated: true)
                        }
                    } else {
                        let annotation = SpotMapAnnotation(
                            spot: entry.spot,
                            coordinate: entry.coordinate,
                            visualState: resolvedState
                        )
                        renderedAnnotations[id] = annotation
                        toAdd.append(annotation)
                    }
                }
            }

            for (id, ann) in renderedAnnotations where !nextAnnotationKeys.contains(id) {
                renderedAnnotations.removeValue(forKey: id)
                animatedSpotIds.remove(id)
                if let view = map.view(for: ann) as? SpotAnnotationView {
                    view.animateOut { [weak map] in
                        guard let map else { return }
                        map.removeAnnotation(ann)
                    }
                } else {
                    toRemove.append(ann)
                }
            }
            for (key, ann) in renderedClusters where !nextClusterKeys.contains(key) {
                renderedClusters.removeValue(forKey: key)
                toRemove.append(ann)
            }

            if !toRemove.isEmpty {
                map.removeAnnotations(toRemove)
                SpotLogger.log(MapMarkerLogs.markersRemoved, details: ["count": toRemove.count])
            }
            if !toAdd.isEmpty {
                map.addAnnotations(toAdd)
                SpotLogger.log(MapMarkerLogs.markersAdded, details: ["count": toAdd.count])
            }
        }

        // MARK: - User marker

        func applyUserMarker(map: MKMapView, marker: SpotUserLocationAnnotation?, suppressDefault: Bool) {
            map.showsUserLocation = !(suppressDefault || marker != nil)

            guard let marker else {
                if let prev = renderedUserAnnotation {
                    ewMapLog("applyUserMarker removing marker (host passed nil)")
                    map.removeAnnotation(prev)
                    renderedUserAnnotation = nil
                }
                return
            }

            if let existing = renderedUserAnnotation {
                if existing.coordinate.latitude != marker.coordinate.latitude
                    || existing.coordinate.longitude != marker.coordinate.longitude {
                    existing.coordinate = marker.coordinate
                }
                existing.profileImageURL = marker.profileImageURL
                existing.username = marker.username
                existing.kind = marker.kind
                if let view = map.view(for: existing) as? UserLocationAnnotationView {
                    view.configure(with: existing)
                }
            } else {
                ewMapLog("applyUserMarker adding marker lat=\(marker.coordinate.latitude) lon=\(marker.coordinate.longitude)")
                map.addAnnotation(marker)
                renderedUserAnnotation = marker
            }
            SpotLogger.log(MapMarkerLogs.userMarkerConfigured, details: [
                "kind": marker.kind == .pro ? "pro" : "regular",
                "hasProfileURL": !(marker.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                "hasUsername": !(marker.username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            ])
        }

        // MARK: - Camera

        func applyCameraIntent(map: MKMapView, intent: SharedSpotMapCameraIntent) {
            guard intent != lastAppliedCameraIntent else {
                if case let .region(region, _) = intent {
                    ewMapLog("applyCameraIntent SKIPPED duplicate region lat=\(region.center.latitude) lon=\(region.center.longitude)")
                }
                return
            }
            lastAppliedCameraIntent = intent
            switch intent {
            case .none:
                return
            case let .region(region, animated):
                ewMapLog("applyCameraIntent .region lat=\(region.center.latitude) lon=\(region.center.longitude) span=\(region.span.latitudeDelta) animated=\(animated) mapBounds=\(map.bounds.size.width)x\(map.bounds.size.height)")
                didApplyExplicitCameraFromParent = true
                ignoreNextRegionChange = true
                map.setRegion(region, animated: animated)
            case let .fitAll(animated):
                didApplyExplicitCameraFromParent = true
                let spotAnnotations = map.annotations.filter { !($0 is MKUserLocation) }
                guard !spotAnnotations.isEmpty else { return }
                ignoreNextRegionChange = true
                map.showAnnotations(spotAnnotations, animated: animated)
            case let .focus(coord, span, lift, animated):
                didApplyExplicitCameraFromParent = true
                let lifted = liftedCoordinate(for: coord, span: span, mapHeight: map.bounds.height, liftPoints: lift)
                let region = MKCoordinateRegion(center: lifted, span: span)
                ignoreNextRegionChange = true
                map.setRegion(region, animated: animated)
            }
        }

        private func liftedCoordinate(
            for coord: CLLocationCoordinate2D,
            span: MKCoordinateSpan,
            mapHeight: CGFloat,
            liftPoints: CGFloat
        ) -> CLLocationCoordinate2D {
            guard mapHeight > 0, liftPoints > 0 else { return coord }
            let latPerPoint = span.latitudeDelta / Double(mapHeight)
            return CLLocationCoordinate2D(
                latitude: coord.latitude - latPerPoint * Double(liftPoints),
                longitude: coord.longitude
            )
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let user = annotation as? SpotUserLocationAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: UserLocationAnnotationView.reuseIdentifier,
                    for: user
                ) as? UserLocationAnnotationView ?? UserLocationAnnotationView(
                    annotation: user,
                    reuseIdentifier: UserLocationAnnotationView.reuseIdentifier
                )
                view.configure(with: user)
                // The viewer's location must remain visible even when a Spot
                // shares the same coordinate.
                view.displayPriority = .required
                view.zPriority = .max
                return view
            }

            if let cluster = annotation as? SpotSoftClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: SoftClusterAnnotationView.reuseIdentifier,
                    for: cluster
                ) as? SoftClusterAnnotationView ?? SoftClusterAnnotationView(
                    annotation: cluster,
                    reuseIdentifier: SoftClusterAnnotationView.reuseIdentifier
                )
                view.configure(with: cluster)
                SpotLogger.log(MapMarkerLogs.softClusterShown, details: ["members": cluster.memberCount])
                return view
            }

            guard let spot = annotation as? SpotMapAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: SpotAnnotationView.reuseIdentifier,
                for: spot
            ) as? SpotAnnotationView ?? SpotAnnotationView(
                annotation: spot,
                reuseIdentifier: SpotAnnotationView.reuseIdentifier
            )
            // No MKMapView clustering — we own density via `SpotSoftClusterAnnotation`.
            view.clusteringIdentifier = nil
            view.apply(state: spot.visualState, animated: false)
            if let id = spot.spot.id, !animatedSpotIds.contains(id) {
                animatedSpotIds.insert(id)
                let delay = MapAnimationDelay.delay(forSpotId: id, fallback: spot.coordinate)
                view.animateInIfNeeded(delay: delay)
            }
            SpotLogger.log(MapMarkerLogs.markerReused, details: ["spotId": spot.spot.id ?? "nil"])
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? SpotSoftClusterAnnotation {
                if let cv = view as? SoftClusterAnnotationView { cv.animatePressIn(); cv.animatePressOut() }
                let span = MKCoordinateSpan(
                    latitudeDelta: max(mapView.region.span.latitudeDelta * 0.35, 0.01),
                    longitudeDelta: max(mapView.region.span.longitudeDelta * 0.35, 0.01)
                )
                ignoreNextRegionChange = true
                mapView.setRegion(MKCoordinateRegion(center: cluster.coordinate, span: span), animated: true)
                mapView.deselectAnnotation(cluster, animated: false)
                return
            }

            guard let ann = view.annotation as? SpotMapAnnotation else { return }
            if let v = view as? SpotAnnotationView {
                v.apply(state: .selected, animated: true)
            }
            SpotLogger.log(MapMarkerLogs.markerSelected, details: ["spotId": ann.spot.id ?? "nil"])
            let regionSnapshot = mapView.region
            parent.onSelect(ann.spot, ann.coordinate, regionSnapshot)
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard let ann = view.annotation as? SpotMapAnnotation else { return }
            if let v = view as? SpotAnnotationView {
                v.apply(state: ann.visualState == .selected ? .default : ann.visualState, animated: true)
            }
            SpotLogger.log(MapMarkerLogs.markerDeselected, details: ["spotId": ann.spot.id ?? "nil"])
            parent.onDeselect()
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated _: Bool) {
            if ignoreNextRegionChange {
                ignoreNextRegionChange = false
                return
            }
            // Adaptive debounce: faster pans (large delta) wait a bit longer.
            regionDebounceTask?.cancel()
            let region = mapView.region
            let parent = self.parent
            regionDebounceTask = Task { [weak self] in
                let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
                let nanos: UInt64 = span > 0.5
                    ? Constants.MapDesign.regionDebounceSlowNs
                    : Constants.MapDesign.regionDebounceFastNs
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let coordinator = self else { return }
                    let bounds = mapView.bounds
                    let layoutReady = bounds.width >= 64 && bounds.height >= 64
                    // Ignore only clearly invalid early layout callbacks.
                    guard layoutReady else {
                        return
                    }
                    let spanMax = max(region.span.latitudeDelta, region.span.longitudeDelta)
                    // Before the parent applies a camera intent, skip obvious
                    // world/continental default regions from MapKit startup.
                    // But still allow user-driven/manual zoom regions through
                    // so fetches can recover even if location fix is delayed.
                    if !coordinator.didApplyExplicitCameraFromParent, spanMax > 15 {
                        return
                    }
                    parent.onRegionChanged(region)
                }
                _ = self
            }
        }
    }
}

// MARK: - Density helpers

extension SharedSpotMap {

    fileprivate func resolved(spots: [Spot], withOverlap: Bool) -> [(spot: Spot, coordinate: CLLocationCoordinate2D)] {
        if withOverlap {
            return MapOverlapResolver().resolve(spots)
        }
        return spots.compactMap { s in
            guard let lat = s.latitude, let lon = s.longitude else { return nil }
            return (s, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    /// Build soft clusters at far zoom: up to `farZoomPinCap` individual
    /// pins; remaining spots collapse into a small number of clusters
    /// keyed by a coarse grid. This is how we avoid both `184+` numeric
    /// bubbles and unbounded annotation counts at world zoom.
    fileprivate func softClusters(
        for spots: [Spot]
    ) -> [(spot: Spot, coordinate: CLLocationCoordinate2D, isCluster: Bool, clusterMemberIds: [String])] {
        let cap = Constants.MapDesign.farZoomPinCap
        let withCoords = spots.compactMap { s -> (Spot, CLLocationCoordinate2D)? in
            guard let lat = s.latitude, let lon = s.longitude else { return nil }
            return (s, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        if withCoords.count <= cap {
            return withCoords.map { ($0.0, $0.1, false, []) }
        }
        // Bucket the overflow with a coarse grid (~0.05° ≈ ~5 km cells).
        let bucketSize = 0.05
        var buckets: [String: [(Spot, CLLocationCoordinate2D)]] = [:]
        for entry in withCoords {
            let key = String(format: "%.2f,%.2f",
                             (entry.1.latitude / bucketSize).rounded() * bucketSize,
                             (entry.1.longitude / bucketSize).rounded() * bucketSize)
            buckets[key, default: []].append(entry)
        }
        var output: [(spot: Spot, coordinate: CLLocationCoordinate2D, isCluster: Bool, clusterMemberIds: [String])] = []
        for (_, members) in buckets {
            if members.count == 1 {
                let only = members[0]
                output.append((only.0, only.1, false, []))
            } else {
                let lat = members.map { $0.1.latitude }.reduce(0, +) / Double(members.count)
                let lon = members.map { $0.1.longitude }.reduce(0, +) / Double(members.count)
                let memberIds = members.compactMap { $0.0.id }
                let placeholderSpot = members[0].0
                output.append((placeholderSpot, CLLocationCoordinate2D(latitude: lat, longitude: lon), true, memberIds))
            }
        }
        return output
    }
}
