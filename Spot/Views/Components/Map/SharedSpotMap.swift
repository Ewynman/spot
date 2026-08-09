//
//  SharedSpotMap.swift
//  Spot
//
//  The single, reusable `MKMapView` host that powers both the discovery
//  map and the profile map.
//
//  Memory / behavior rules:
//   * Force light mode; no POIs, no traffic, flat elevation.
//   * Reuse `SpotAnnotationView`, `SpotClusterAnnotationView`,
//     `UserLocationAnnotationView` via stable identifiers.
//   * Diff annotations by spot id (never wholesale remove+add).
//   * Camera moves are explicit via `cameraIntent`.
//   * Density uses MapKit clustering (`clusteringIdentifier`).
//   * `dismantleUIView` releases delegate, annotations, overlays.
//

import SwiftUI
import MapKit

// MARK: - Camera intent

enum SharedSpotMapCameraIntent: Equatable {
    case none
    case region(MKCoordinateRegion, animated: Bool)
    case fitAll(animated: Bool)
    case focus(coordinate: CLLocationCoordinate2D,
               span: MKCoordinateSpan,
               liftPoints: CGFloat,
               animated: Bool)
    case fitAnnotations([CLLocationCoordinate2D], animated: Bool)

    static func == (lhs: SharedSpotMapCameraIntent, rhs: SharedSpotMapCameraIntent) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case let (.region(a, x), .region(b, y)): return regionsEqual(a, b) && x == y
        case let (.fitAll(x), .fitAll(y)): return x == y
        case let (.focus(c1, s1, l1, a1), .focus(c2, s2, l2, a2)):
            return c1.latitude == c2.latitude && c1.longitude == c2.longitude
                && s1.latitudeDelta == s2.latitudeDelta && s1.longitudeDelta == s2.longitudeDelta
                && l1 == l2 && a1 == a2
        case let (.fitAnnotations(a, ax), .fitAnnotations(b, bx)):
            guard ax == bx, a.count == b.count else { return false }
            return zip(a, b).allSatisfy {
                $0.0.latitude == $0.1.latitude && $0.0.longitude == $0.1.longitude
            }
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

    let spots: [Spot]
    let selectedSpotId: String?
    let filter: SpotMapFilterState
    let savedSpotIds: Set<String>
    let likedSpotIds: Set<String>
    let followedUserIds: Set<String>

    let userMarker: SpotUserLocationAnnotation?
    let suppressDefaultUserDot: Bool

    let cameraIntent: SharedSpotMapCameraIntent

    /// `MKCoordinateRegion` is `mapView.region` immediately before pin-focus.
    let onSelect: (Spot, CLLocationCoordinate2D, MKCoordinateRegion) -> Void
    let onDeselect: () -> Void
    let onRegionChanged: (MKCoordinateRegion) -> Void
    /// Cluster members that cannot be split further — host should show carousel.
    var onCoincidentCluster: (([Spot]) -> Void)? = nil
    var onClusterTapped: ((Int) -> Void)? = nil

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsTraffic = false
        map.showsCompass = false
        map.showsScale = false
        map.showsBuildings = false
        map.showsUserLocation = !(suppressDefaultUserDot || userMarker != nil)

        if #available(iOS 13.0, *) {
            map.overrideUserInterfaceStyle = .light
            let cfg = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            cfg.pointOfInterestFilter = .excludingAll
            map.preferredConfiguration = cfg
        }

        map.register(SpotAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: SpotAnnotationView.reuseIdentifier)
        map.register(SpotClusterAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: SpotClusterAnnotationView.reuseIdentifier)
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
        private var renderedUserAnnotation: SpotUserLocationAnnotation?
        private var lastAppliedCameraIntent: SharedSpotMapCameraIntent = .none
        private var regionDebounceTask: Task<Void, Never>?
        private var animatedSpotIds: Set<String> = []
        private var ignoreNextRegionChange: Bool = false
        private var didApplyExplicitCameraFromParent = false
        /// Suppress `onDeselect` when selection is driven by SwiftUI state.
        private var suppressDeselectCallback = false

        init(_ parent: SharedSpotMap) {
            self.parent = parent
        }

        func attach(map _: MKMapView) {}

        func detach(map _: MKMapView) {
            regionDebounceTask?.cancel()
            renderedAnnotations.removeAll()
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

            let displayed = parent.resolved(spots: modelSpots)

            var nextAnnotationKeys = Set<String>()
            var toAdd: [MKAnnotation] = []
            var toRemove: [MKAnnotation] = []

            for entry in displayed {
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

            if !toRemove.isEmpty {
                map.removeAnnotations(toRemove)
                SpotLogger.log(MapMarkerLogs.markersRemoved, details: ["count": toRemove.count])
            }
            if !toAdd.isEmpty {
                map.addAnnotations(toAdd)
                SpotLogger.log(MapMarkerLogs.markersAdded, details: ["count": toAdd.count])
            }

            // Keep MapKit selection in sync with SwiftUI selection without
            // firing a spurious deselect → dismiss cycle.
            syncSelection(map: map, selectedSpotId: selectedSpotId)
        }

        private func syncSelection(map: MKMapView, selectedSpotId: String?) {
            let currentlySelected = map.selectedAnnotations.compactMap { $0 as? SpotMapAnnotation }
            if let id = selectedSpotId, let ann = renderedAnnotations[id] {
                if !currentlySelected.contains(where: { $0.spotId == id }) {
                    suppressDeselectCallback = true
                    for sel in currentlySelected {
                        map.deselectAnnotation(sel, animated: false)
                    }
                    map.selectAnnotation(ann, animated: false)
                    suppressDeselectCallback = false
                }
            } else if !currentlySelected.isEmpty {
                suppressDeselectCallback = true
                for sel in currentlySelected {
                    map.deselectAnnotation(sel, animated: false)
                }
                suppressDeselectCallback = false
            }
        }

        // MARK: - User marker

        func applyUserMarker(map: MKMapView, marker: SpotUserLocationAnnotation?, suppressDefault: Bool) {
            map.showsUserLocation = !(suppressDefault || marker != nil)

            guard let marker else {
                if let prev = renderedUserAnnotation {
                    SpotLogger.log(MapMarkerLogs.userMarkerRemoved)
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
                    SpotLogger.log(MapViewLogs.cameraIntentSkippedDuplicate, details: [
                        "lat": region.center.latitude,
                        "lon": region.center.longitude
                    ])
                }
                return
            }
            lastAppliedCameraIntent = intent
            switch intent {
            case .none:
                return
            case let .region(region, animated):
                SpotLogger.log(MapViewLogs.cameraIntentApplied, details: [
                    "kind": "region",
                    "lat": region.center.latitude,
                    "lon": region.center.longitude,
                    "span": region.span.latitudeDelta,
                    "animated": animated,
                    "mapHeight": Int(map.bounds.height)
                ])
                didApplyExplicitCameraFromParent = true
                ignoreNextRegionChange = true
                map.setRegion(region, animated: animated)
            case let .fitAll(animated):
                didApplyExplicitCameraFromParent = true
                let spotAnnotations = map.annotations.filter {
                    $0 is SpotMapAnnotation || $0 is MKClusterAnnotation
                }
                guard !spotAnnotations.isEmpty else { return }
                ignoreNextRegionChange = true
                map.showAnnotations(spotAnnotations, animated: animated)
            case let .focus(coord, span, lift, animated):
                didApplyExplicitCameraFromParent = true
                let lifted = MapCameraLift.liftedCoordinate(
                    for: coord,
                    span: span,
                    mapHeight: map.bounds.height,
                    liftPoints: lift
                )
                let region = MKCoordinateRegion(center: lifted, span: span)
                ignoreNextRegionChange = true
                map.setRegion(region, animated: animated)
            case let .fitAnnotations(coords, animated):
                didApplyExplicitCameraFromParent = true
                guard !coords.isEmpty else { return }
                ignoreNextRegionChange = true
                var zoomRect = MKMapRect.null
                for c in coords {
                    let point = MKMapPoint(c)
                    let rect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                    zoomRect = zoomRect.union(rect)
                }
                let inset = UIEdgeInsets(top: 80, left: 60, bottom: 160, right: 60)
                map.setVisibleMapRect(zoomRect, edgePadding: inset, animated: animated)
            }
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
                view.displayPriority = .required
                view.zPriority = .max
                view.clusteringIdentifier = nil
                return view
            }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: SpotClusterAnnotationView.reuseIdentifier,
                    for: cluster
                ) as? SpotClusterAnnotationView ?? SpotClusterAnnotationView(
                    annotation: cluster,
                    reuseIdentifier: SpotClusterAnnotationView.reuseIdentifier
                )
                view.configure(with: cluster)
                SpotLogger.log(MapMarkerLogs.softClusterShown, details: [
                    "members": cluster.memberAnnotations.count
                ])
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
            view.clusteringIdentifier = Constants.MapDesign.spotClusteringIdentifier
            view.apply(state: spot.visualState, animated: false)
            if let id = spot.spot.id, !animatedSpotIds.contains(id) {
                animatedSpotIds.insert(id)
                let delay = MapAnimationDelay.delay(forSpotId: id, fallback: spot.coordinate)
                view.animateInIfNeeded(delay: delay)
            }
            let username = spot.spot.username ?? "someone"
            let place = spot.spot.locationName ?? "a spot"
            view.accessibilityLabel = "Spot by \(username), \(place). Double-tap to preview."
            view.accessibilityTraits = .button
            SpotLogger.log(MapMarkerLogs.markerReused, details: ["spotId": spot.spot.id ?? "nil"])
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                handleClusterTap(mapView: mapView, cluster: cluster)
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

        private func handleClusterTap(mapView: MKMapView, cluster: MKClusterAnnotation) {
            let members = cluster.memberAnnotations
            let count = members.count
            parent.onClusterTapped?(count)

            let memberSpots = members.compactMap { ($0 as? SpotMapAnnotation)?.spot }
            if MapClusterStyle.isCoincident(members), !memberSpots.isEmpty {
                parent.onCoincidentCluster?(memberSpots)
                return
            }

            ignoreNextRegionChange = true
            didApplyExplicitCameraFromParent = true
            mapView.showAnnotations(members, animated: true)
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard let ann = view.annotation as? SpotMapAnnotation else { return }
            if let v = view as? SpotAnnotationView {
                let next = ann.visualState == .selected ? SpotMarkerVisualState.default : ann.visualState
                v.apply(state: next == .selected ? .default : next, animated: true)
            }
            SpotLogger.log(MapMarkerLogs.markerDeselected, details: ["spotId": ann.spot.id ?? "nil"])
            guard !suppressDeselectCallback else { return }
            // Defer: pin switches fire didDeselect before didSelect; only
            // dismiss when nothing is selected after a turn of the run loop.
            let priorId = ann.spotId
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self else { return }
                guard !self.suppressDeselectCallback else { return }
                let stillSelected = mapView.selectedAnnotations.contains {
                    ($0 as? SpotMapAnnotation)?.spotId != nil
                }
                guard !stillSelected else { return }
                // If SwiftUI selection already moved to another spot, skip.
                if let selected = self.parent.selectedSpotId, selected != priorId {
                    return
                }
                self.parent.onDeselect()
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated _: Bool) {
            if ignoreNextRegionChange {
                ignoreNextRegionChange = false
                return
            }
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
                    guard layoutReady else { return }
                    let spanMax = max(region.span.latitudeDelta, region.span.longitudeDelta)
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

// MARK: - Coordinate helpers

extension SharedSpotMap {

    fileprivate func resolved(spots: [Spot]) -> [(spot: Spot, coordinate: CLLocationCoordinate2D)] {
        spots.compactMap { s in
            guard let lat = s.latitude, let lon = s.longitude else { return nil }
            return (s, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }
}
