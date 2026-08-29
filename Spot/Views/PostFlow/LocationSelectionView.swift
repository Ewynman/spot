//
//  LocationSelectionView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct LocationSelectionView: View {
    @Binding var selectedLocation: LocationData?
    var onLocationConfirmed: ((LocationData) -> Void)?
    @StateObject private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var nearbyPlaces: [MKMapItem] = []
    @State private var currentLocation: CLLocation?
    @State private var region = MKCoordinateRegion(
        center: MapDefaults.continentalUSCenter,
        span: MapDefaults.continentalUSSpan
    )
    @State private var showingMap = false
    @State private var isSearching = false
    @State private var isLoadingNearby = true
    @State private var nearbyRadius = LocationSearchPolicy.nearbyRadiusMeters
    @State private var nearbySearch: MKLocalSearch?
    @State private var textSearch: MKLocalSearch?
    @State private var showCustomNameAlert = false
    @State private var pendingCustomName: String = ""
    @State private var showBlockedAlert = false
    @State private var blockedReason: String = ""
    @FocusState private var searchFieldFocused: Bool
    private let searchDebouncer = Debouncer(interval: 0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.extraLarge) {
            header
            if let location = selectedLocation {
                selectedLocationCard(location)
            }
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nearbyContent
            } else {
                searchContent
            }
        }
        .padding(.horizontal, Constants.Layout.Padding.horizontal)
        .padding(.bottom, Constants.Layout.Padding.verticalLarge)
        .onAppear {
            loadNearbyPlaces()
        }
        .onDisappear {
            searchDebouncer.cancel()
            nearbySearch?.cancel()
            textSearch?.cancel()
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            guard let newLocation else { return }
            guard LocationSearchPolicy.shouldRefreshNearby(from: currentLocation, to: newLocation) else { return }
            currentLocation = newLocation
            nearbyRadius = LocationSearchPolicy.nearbyRadiusMeters
            searchNearbyPlaces(around: newLocation, radius: nearbyRadius)
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .denied || status == .restricted {
                isLoadingNearby = false
            }
        }
        .sheet(isPresented: $showingMap) {
            if let selectedLocation {
                LocationMapView(location: selectedLocation, onConfirm: { location in
                    self.selectedLocation = location
                    showingMap = false
                    onLocationConfirmed?(location)
                })
            }
        }
        .alert("Set custom location name", isPresented: $showCustomNameAlert) {
            TextField("e.g. Utopia of the Seas", text: $pendingCustomName)
            Button("Save") { applyCustomName() }
            Button("Cancel", role: .cancel) { pendingCustomName = "" }
        } message: {
            Text("This will be shown instead of the city/state.")
        }
        .alert("Name not allowed", isPresented: $showBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blockedReason)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.large) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where’s your Spot?")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                Text("Search for the place or choose one near you.")
                    .font(.system(size: 16))
                    .foregroundColor(Constants.Colors.welcomeMutedText)
            }

            HStack(spacing: Constants.Layout.Spacing.medium) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search a place, venue, or address")
                        .foregroundColor(Constants.Colors.primary.opacity(0.62))
                )
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .tint(Constants.Colors.primary)
                    .focused($searchFieldFocused)
                    .submitLabel(.search)
                    .onChange(of: searchText) { _, query in
                        searchDebouncer.schedule {
                            searchPlaces(query: query)
                        }
                    }
                    .onSubmit {
                        searchDebouncer.cancel()
                        searchPlaces(query: searchText)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchDebouncer.cancel()
                        textSearch?.cancel()
                        searchText = ""
                        searchResults = []
                        isSearching = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Constants.Colors.welcomeMutedText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Constants.Layout.Padding.verticalLarge)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large)
                    .stroke(
                        searchFieldFocused ? Constants.Colors.primary : Constants.Colors.welcomeLine.opacity(0.45),
                        lineWidth: searchFieldFocused ? 1.5 : 1
                    )
            }
            .shadow(color: Constants.Colors.welcomeCardShadow.opacity(0.35), radius: 10, y: 4)
            .accessibilityIdentifier("locationSearchField")
        }
        .padding(.top, Constants.Layout.Padding.verticalSmall)
    }

    @ViewBuilder
    private var nearbyContent: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            sectionHeader(
                title: "Near you",
                subtitle: nearbyRadius == LocationSearchPolicy.nearbyRadiusMeters
                    ? "Closest places first"
                    : "Showing a wider area"
            )

            if isLoadingNearby {
                statusCard(icon: nil, title: "Finding places around you", showsProgress: true)
            } else if currentLocation == nil {
                statusCard(
                    icon: "location.slash",
                    title: "Location isn’t available",
                    message: "Search for a place above to keep going."
                )
            } else if nearbyPlaces.isEmpty {
                statusCard(
                    icon: "mappin.slash",
                    title: "No places found nearby",
                    message: "Try a wider area or search by name."
                )
                widerAreaButton
            } else {
                LazyVStack(spacing: Constants.Layout.Spacing.medium) {
                    ForEach(nearbyPlaces, id: \.self) { item in
                        ImprovedLocationRow(item: item, origin: currentLocation) { location in
                            select(location)
                        }
                    }
                }

                if nearbyRadius < LocationSearchPolicy.expandedNearbyRadiusMeters {
                    widerAreaButton
                }
            }
        }
        .accessibilityIdentifier("nearbyPlacesSection")
    }

    @ViewBuilder
    private var searchContent: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            sectionHeader(title: "Search results", subtitle: "Best matches near you")

            if isSearching {
                statusCard(icon: nil, title: "Searching places", showsProgress: true)
            } else if searchResults.isEmpty {
                statusCard(
                    icon: "magnifyingglass",
                    title: "No matching places",
                    message: "Check the spelling or add it as a custom place."
                )
                customPlaceButton
            } else {
                LazyVStack(spacing: Constants.Layout.Spacing.medium) {
                    ForEach(searchResults, id: \.self) { item in
                        ImprovedLocationRow(item: item, origin: currentLocation) { location in
                            select(location)
                        }
                    }
                    customPlaceButton
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.welcomeMutedText)
            }
            Spacer()
            if title == "Near you", !isLoadingNearby, !nearbyPlaces.isEmpty {
                Text("\(nearbyPlaces.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Constants.Colors.accent)
                    .clipShape(Capsule())
            }
        }
    }

    private func statusCard(
        icon: String?,
        title: String,
        message: String? = nil,
        showsProgress: Bool = false
    ) -> some View {
        VStack(spacing: Constants.Layout.Spacing.medium) {
            if showsProgress {
                ProgressView()
                    .tint(Constants.Colors.primary)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundColor(Constants.Colors.primary)
            }
            Text(title)
                .font(FontManager.primaryText())
                .fontWeight(.medium)
                .foregroundColor(Constants.Colors.primary)
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.welcomeMutedText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Layout.Padding.verticalExtraLarge)
        .padding(.horizontal, Constants.Layout.Padding.verticalLarge)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large))
    }

    private var widerAreaButton: some View {
        Button {
            guard let currentLocation else { return }
            nearbyRadius = LocationSearchPolicy.expandedNearbyRadiusMeters
            searchNearbyPlaces(around: currentLocation, radius: nearbyRadius)
        } label: {
            Label("Search a wider area", systemImage: "scope")
                .font(FontManager.primaryText())
                .fontWeight(.medium)
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Constants.Colors.accent.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }

    private var customPlaceButton: some View {
        Button {
            useSearchTextAsCustomPlace()
        } label: {
            HStack(spacing: Constants.Layout.Spacing.medium) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Constants.Colors.accent)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add “\(searchText)”")
                        .font(FontManager.primaryText())
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("Use a custom place name")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.welcomeMutedText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundColor(Constants.Colors.primary)
            .padding(Constants.Layout.Padding.verticalLarge)
            .background(Constants.Colors.accent.opacity(0.38))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large))
        }
        .buttonStyle(.plain)
    }

    private func selectedLocationCard(_ location: LocationData) -> some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            HStack(spacing: Constants.Layout.Spacing.medium) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(width: 32, height: 32)
                    .background(Constants.Colors.primary)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Spot")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.welcomeMutedText)
                    Text(location.placeName)
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    selectedLocation = nil
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(Constants.Colors.welcomeMutedText)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove selected place")
            }

            HStack(spacing: Constants.Layout.Spacing.small) {
                selectionAction(title: "Adjust pin", icon: "map") {
                    showingMap = true
                }
                selectionAction(title: "Rename", icon: "pencil") {
                    promptCustomName()
                }
            }
        }
        .padding(Constants.Layout.Padding.verticalLarge)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large)
                .stroke(Constants.Colors.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private func selectionAction(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(Constants.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Constants.Colors.accent.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.small))
        }
        .buttonStyle(.plain)
    }

    private func loadNearbyPlaces() {
        SpotLogger.log(LocationSelectionViewLogs.loadingNearbyPlaces)
        locationManager.ensureAuthorizationAndStart()

        guard let location = locationManager.userLocation else {
            SpotLogger.log(LocationSelectionViewLogs.noCurrentLocationAvailable)
            isLoadingNearby = locationManager.authorizationStatus != .denied
                && locationManager.authorizationStatus != .restricted
            return
        }

        currentLocation = location
        searchNearbyPlaces(around: location, radius: nearbyRadius)
    }

    private func searchNearbyPlaces(around location: CLLocation, radius: CLLocationDistance) {
        SpotLogger.log(LocationSelectionViewLogs.gotCurrentLocation, details: [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "radiusMeters": radius
        ])
        nearbySearch?.cancel()
        isLoadingNearby = true
        region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
        let search = MKLocalSearch(request: request)
        nearbySearch = search
        search.start { response, error in
            DispatchQueue.main.async {
                guard self.nearbySearch === search else { return }
                self.isLoadingNearby = false
                if let error = error {
                    SpotLogger.log(LocationSelectionViewLogs.nearbyPlaceSearchFailed, details: ["error": error.localizedDescription])
                } else if let response = response {
                    SpotLogger.log(LocationSelectionViewLogs.foundNearbyPlaces, details: ["count": response.mapItems.count])
                    self.nearbyPlaces = LocationSearchPolicy.sortedByDistance(
                        response.mapItems,
                        from: location,
                        limit: LocationSearchPolicy.maximumNearbyResults
                    )
                }
            }
        }
    }

    private func searchPlaces(query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        textSearch?.cancel()
        guard !normalizedQuery.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        SpotLogger.log(LocationSelectionViewLogs.searchingPlaces, details: ["query": normalizedQuery])

        func runSearch(in searchRegion: MKCoordinateRegion?, completion: @escaping ([MKMapItem]) -> Void) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = normalizedQuery
            request.resultTypes = [.pointOfInterest, .address]
            if let searchRegion {
                request.region = searchRegion
            }
            let search = MKLocalSearch(request: request)
            textSearch = search
            search.start { response, error in
                guard self.textSearch === search else { return }
                if let error = error {
                    SpotLogger.log(LocationSelectionViewLogs.searchPlacesFailed, details: ["error": error.localizedDescription])
                    completion([])
                } else {
                    completion(response?.mapItems ?? [])
                }
            }
        }

        let localRegion = LocationSearchPolicy.localSearchRegion(around: region.center)
        runSearch(in: localRegion) { first in
            DispatchQueue.main.async {
                guard self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedQuery else { return }
                if !first.isEmpty {
                    SpotLogger.log(LocationSelectionViewLogs.foundLocalSearchResults, details: ["count": first.count, "query": normalizedQuery])
                    self.searchResults = Array(first.prefix(LocationSearchPolicy.maximumSearchResults))
                    self.isSearching = false
                } else {
                    SpotLogger.log(LocationSelectionViewLogs.noLocalResultsRetryingGlobal)
                    runSearch(in: nil) { global in
                        DispatchQueue.main.async {
                            guard self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedQuery else { return }
                            SpotLogger.log(LocationSelectionViewLogs.foundGlobalSearchResults, details: ["count": global.count, "query": normalizedQuery])
                            self.searchResults = Array(global.prefix(LocationSearchPolicy.maximumSearchResults))
                            self.isSearching = false
                        }
                    }
                }
            }
        }
    }

    private func select(_ location: LocationData) {
        selectedLocation = location
        showingMap = true
        searchFieldFocused = false
    }

    private func useSearchTextAsCustomPlace() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        select(
            LocationData(
                coordinate: currentLocation?.coordinate ?? region.center,
                placeName: name,
                address: nil,
                isCustomName: true
            )
        )
    }

    private func promptCustomName() {
        pendingCustomName = selectedLocation?.placeName ?? ""
        showCustomNameAlert = true
    }

    private func applyCustomName() {
        let name = pendingCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, var current = selectedLocation else { return }
        // Validate with BlockedTerms
        let validator = PlaceNameValidator()
        let validation = validator.validate(name)
        switch validation {
        case .ok:
            break
        case .tooShort, .tooLong, .blocked:
            blockedReason = PlaceNameFeedback.message(for: validation) ?? "That name isn’t allowed."
            showBlockedAlert = true
            pendingCustomName = ""
            showCustomNameAlert = false
            return
        }
        current = LocationData(
            coordinate: current.coordinate,
            placeName: name,
            address: current.address,
            isCustomName: true
        )
        selectedLocation = current
        pendingCustomName = ""
        showCustomNameAlert = false
    }
}

// MARK: - Canonical places support
struct CanonicalPlace: Decodable {
    let name: String
    let aliases: [String]
    let latitude: Double
    let longitude: Double
    let address: String?

    func matches(_ q: String) -> Bool {
        CanonicalPlaceMatcher.matches(name: name, aliases: aliases, query: q)
    }

    static func load() -> [CanonicalPlace] {
        guard let url = Bundle.main.url(forResource: "CanonicalPlaces", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let places = try? JSONDecoder().decode([CanonicalPlace].self, from: data) else {
            return []
        }
        return places
    }
}

// MARK: - Improved Location Row
struct ImprovedLocationRow: View {
    let item: MKMapItem
    let origin: CLLocation?
    let onSelect: (LocationData) -> Void
    
    private var distanceText: String? {
        LocationSearchPolicy.distanceText(for: item, from: origin)
    }

    private var subtitle: String? {
        LocationPlacemarkFormatter.subtitle(
            city: item.placemark.locality,
            state: item.placemark.administrativeArea,
            title: item.placemark.title
        )
    }

    var body: some View {
        Button(action: {
            let city = item.placemark.locality
            let state = item.placemark.administrativeArea
            let country = item.placemark.country
            let locationData = LocationData(
                coordinate: item.placemark.coordinate,
                placeName: LocationPlacemarkFormatter.placeName(
                    itemName: item.name,
                    city: city,
                    state: state,
                    country: country
                ),
                address: LocationPlacemarkFormatter.address(city: city, state: state, country: country),
                isCustomName: false
            )
            
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            SpotLogger.log(LocationSelectionViewLogs.userSelectedLocation, details: ["placeName": locationData.placeName])
            onSelect(locationData)
        }) {
            HStack(spacing: Constants.Layout.Spacing.medium) {
                ZStack {
                    Circle()
                        .fill(Constants.Colors.accent)
                        .frame(width: 42, height: 42)
                    
                    Image("green_marker")
                        .resizable()
                        .frame(width: 21, height: 21)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "Unknown Location")
                        .font(FontManager.primaryText())
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        if let distanceText {
                            Text(distanceText)
                                .fontWeight(.semibold)
                            Circle()
                                .frame(width: 3, height: 3)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Constants.Colors.welcomeMutedText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Constants.Colors.welcomeMutedText.opacity(0.75))
            }
            .padding(Constants.Layout.Padding.verticalLarge)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.large)
                    .stroke(Constants.Colors.primary.opacity(0.08), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Location Map View
struct LocationMapView: View {
    let location: LocationData
    let onConfirm: (LocationData) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var draggedLocation: LocationData
    @State private var currentLocationName: String
    @State private var geocodeWorkItem: DispatchWorkItem?
    private let geocoder = CLGeocoder()
    @State private var isGeocoding = false
    @State private var geocodeRequestID = UUID()
    private let geocodeDebouncer = Debouncer(interval: 0.5)
    @State private var markerScale: CGFloat = 1.0
    @State private var initialLocation: LocationData
    @State private var hasUserMoved = false

    init(location: LocationData, onConfirm: @escaping (LocationData) -> Void) {
        self.location = location
        self.onConfirm = onConfirm
        let optimalSpan = Self.calculateOptimalSpan(for: location)
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: optimalSpan
        )
        _position = State(initialValue: .region(region))
        _draggedLocation = State(initialValue: location)
        _currentLocationName = State(initialValue: location.placeName)
        _initialLocation = State(initialValue: location)
    }
    
    private static func calculateOptimalSpan(for location: LocationData) -> MKCoordinateSpan {
        LocationMapCameraPolicy.optimalSpan(for: location)
    }
    

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    // Blue dot (appears when permission granted)
                    UserAnnotation()
                }
                // Debounced center updates while the map moves continuously
                .onMapCameraChange(frequency: .continuous) { context in
                    let center = context.region.center
                    let moved = LocationSelectionPolicy.hasMeaningfullyMoved(
                        from: initialLocation.coordinate,
                        to: center
                    )
                    hasUserMoved = moved
                    guard moved else {
                        geocodeDebouncer.cancel()
                        geocoder.cancelGeocode()
                        geocodeRequestID = UUID()
                        isGeocoding = false
                        draggedLocation = initialLocation
                        currentLocationName = initialLocation.placeName
                        return
                    }
                    
                    // Animate marker on drag
                    withAnimation(.easeOut(duration: 0.1)) {
                        markerScale = 0.9
                    }
                    
                    // Move selection immediately (for UI), then reverse-geocode after debounce
                    draggedLocation = LocationData(
                        coordinate: center,
                        placeName: draggedLocation.placeName,
                        address: draggedLocation.address,
                        isCustomName: draggedLocation.isCustomName
                    )
                    geocodeDebouncer.schedule { 
                        self.updateDraggedLocation(to: center)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            markerScale = 1.0
                        }
                    }
                }
                .preferredColorScheme(.light)
                // Center marker overlay (keeps marker fixed; map moves under it)
                .overlay(alignment: .center) {
                    ZStack {
                        // Shadow for depth
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .offset(y: 20)
                            .blur(radius: 4)
                        
                        // Pin marker
                        Image("green_marker")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .scaleEffect(markerScale)
                            .offset(y: -20)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .allowsHitTesting(false)
                }

                // Top “current name” chip
                VStack {
                    HStack(spacing: 8) {
                        if isGeocoding {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Constants.Colors.primary)
                        } else {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Constants.Colors.primary)
                        }
                        Text(currentLocationName)
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                            .lineLimit(1)
                        Spacer()
                        
                        if hasUserMoved {
                            Button(action: resetToInitial) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12))
                                    Text("Reset")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(Constants.Colors.primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()

                    // Confirm button with haptic feedback
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task { await confirmWithUpsert() }
                    }) {
                        HStack {
                            if isGeocoding {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isGeocoding ? "Locating..." : "Confirm Location")
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.buttonText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.primary)
                        .cornerRadius(20)
                        .shadow(color: Constants.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                }
                // Map controls
                .overlay(alignment: .topTrailing) {
                    Button {
                        position = .userLocation(
                            followsHeading: false,
                            fallback: .region(MKCoordinateRegion(
                                center: initialLocation.coordinate,
                                span: Self.calculateOptimalSpan(for: initialLocation)
                            ))
                        )
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Constants.Colors.primary)
                            .frame(width: 44, height: 44)
                            .background(Constants.Colors.background)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Constants.Colors.primary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Center on my location")
                    .padding()
                }
            }
            .navigationTitle("Confirm Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .onAppear {
                // Ensure keyboard is dismissed to avoid input accessory constraint noise
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - Reverse geocode the new center (debounced)
    private func updateDraggedLocation(to newCenter: CLLocationCoordinate2D) {
        geocodeWorkItem?.cancel()
        geocoder.cancelGeocode()
        isGeocoding = true
        let requestID = UUID()
        geocodeRequestID = requestID
        
        let loc = CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, error in
            DispatchQueue.main.async {
                guard self.geocodeRequestID == requestID else { return }
                defer { self.isGeocoding = false }
                if let ns = error as NSError? {
                    if ns.code != CLError.Code.network.rawValue && 
                       ns.code != CLError.Code.geocodeFoundNoResult.rawValue &&
                       ns.code != CLError.Code.geocodeCanceled.rawValue {
                        SpotLogger.log(LocationSelectionViewLogs.reverseGeocodeFailed, details: ["error": ns.localizedDescription])
                    }
                    return
                }
                guard let placemark = placemarks?.first else { return }
                let prettyName = LocationPlacemarkFormatter.reverseGeocodedPlaceName(
                    placemarkName: placemark.name,
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    previousPlaceName: self.draggedLocation.placeName
                )
                let address = LocationPlacemarkFormatter.address(
                    city: placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines),
                    state: placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines),
                    country: placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                let resolvedName = LocationSelectionPolicy.resolvedPlaceName(
                    originalName: self.initialLocation.placeName,
                    reverseGeocodedName: prettyName,
                    isCustomName: self.draggedLocation.isCustomName,
                    hasMeaningfullyMoved: self.hasUserMoved
                )

                self.draggedLocation = LocationData(
                    coordinate: newCenter,
                    placeName: resolvedName,
                    address: address,
                    isCustomName: self.draggedLocation.isCustomName
                )
                self.currentLocationName = resolvedName
            }
        }
    }

    // MARK: - Upsert custom place before returning
    private func confirmWithUpsert() async {
        let selected = draggedLocation
        if selected.isCustomName {
            let validator = PlaceNameValidator()
            switch validator.validate(selected.placeName) {
            case .ok:
                break
            case .tooShort, .tooLong, .blocked:
                SpotLogger.log(LocationSelectionViewLogs.blockedCustomPlaceSkipUpsert)
            }
        }
        onConfirm(selected)
    }
    
    // MARK: - Reset to initial location
    private func resetToInitial() {
        geocodeDebouncer.cancel()
        geocoder.cancelGeocode()
        geocodeRequestID = UUID()
        isGeocoding = false
        withAnimation {
            let optimalSpan = Self.calculateOptimalSpan(for: initialLocation)
            let region = MKCoordinateRegion(
                center: initialLocation.coordinate,
                span: optimalSpan
            )
            position = .region(region)
            draggedLocation = initialLocation
            currentLocationName = initialLocation.placeName
            hasUserMoved = false
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Use typed text as custom place row
struct UseTypedAsCustomRow: View {
    let title: String
    let onUse: () -> Void
    var body: some View {
        Button(action: onUse) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Constants.Colors.primary)
                Text("Use ‘\(title)’ as a custom place")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LocationSelectionView(selectedLocation: .constant(nil))
}
