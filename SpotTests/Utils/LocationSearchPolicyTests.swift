import CoreLocation
import MapKit
import Testing
@testable import Spot

struct LocationSearchPolicyTests {
    @Test func nearbyPlacesAreSortedByDistanceAndLimited() {
        let origin = CLLocation(latitude: 40.0, longitude: -74.0)
        let far = makeItem(name: "Far", latitude: 40.02, longitude: -74.0)
        let close = makeItem(name: "Close", latitude: 40.001, longitude: -74.0)
        let middle = makeItem(name: "Middle", latitude: 40.01, longitude: -74.0)

        let sorted = LocationSearchPolicy.sortedByDistance(
            [far, close, middle],
            from: origin,
            limit: 2
        )

        #expect(sorted.map(\.name) == ["Close", "Middle"])
    }

    @Test func distanceUsesMetersForNearbyPlaces() {
        let origin = CLLocation(latitude: 40.0, longitude: -74.0)
        let item = makeItem(name: "Nearby", latitude: 40.0009, longitude: -74.0)

        let text = LocationSearchPolicy.distanceText(for: item, from: origin)

        #expect(text?.hasSuffix(" m") == true)
    }

    @Test func distanceUsesKilometersForFartherPlaces() {
        let origin = CLLocation(latitude: 40.0, longitude: -74.0)
        let item = makeItem(name: "Farther", latitude: 40.018, longitude: -74.0)

        let text = LocationSearchPolicy.distanceText(for: item, from: origin)

        #expect(text?.hasSuffix(" km") == true)
    }

    @Test func distanceIsHiddenWithoutAnOrigin() {
        let item = makeItem(name: "Place", latitude: 40.0, longitude: -74.0)

        #expect(LocationSearchPolicy.distanceText(for: item, from: nil) == nil)
    }

    @Test func localSearchRegionUsesConfiguredRadius() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

        let region = LocationSearchPolicy.localSearchRegion(around: coordinate)

        #expect(region.center.latitude == coordinate.latitude)
        #expect(region.center.longitude == coordinate.longitude)
        #expect(region.span.latitudeDelta > 0.3)
        #expect(region.span.latitudeDelta < 0.6)
    }

    @Test func nearbyRefreshRequiresMeaningfulMove() {
        let first = CLLocation(latitude: 40.0, longitude: -74.0)
        let near = CLLocation(latitude: 40.0001, longitude: -74.0)
        let far = CLLocation(latitude: 40.01, longitude: -74.0)

        #expect(LocationSearchPolicy.shouldRefreshNearby(from: nil, to: first))
        #expect(!LocationSearchPolicy.shouldRefreshNearby(from: first, to: near))
        #expect(LocationSearchPolicy.shouldRefreshNearby(from: first, to: far))
    }

    private func makeItem(
        name: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees
    ) -> MKMapItem {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
        let item = MKMapItem(placemark: placemark)
        item.name = name
        return item
    }
}

struct LocationSelectionPolicyTests {
    @Test func initialCameraSettleDoesNotCountAsUserMovement() {
        let initial = CLLocationCoordinate2D(latitude: 28.410, longitude: -80.608)
        let nearby = CLLocationCoordinate2D(latitude: 28.41001, longitude: -80.60801)

        #expect(LocationSelectionPolicy.hasMeaningfullyMoved(from: initial, to: nearby) == false)
    }

    @Test func meaningfulPinMovementIsDetected() {
        let initial = CLLocationCoordinate2D(latitude: 28.410, longitude: -80.608)
        let moved = CLLocationCoordinate2D(latitude: 28.411, longitude: -80.608)

        #expect(LocationSelectionPolicy.hasMeaningfullyMoved(from: initial, to: moved))
    }

    @Test func selectedPointOfInterestNameSurvivesInitialReverseGeocode() {
        let name = LocationSelectionPolicy.resolvedPlaceName(
            originalName: "MSC Seashore",
            reverseGeocodedName: "Port Canaveral",
            isCustomName: false,
            hasMeaningfullyMoved: false
        )

        #expect(name == "MSC Seashore")
    }

    @Test func reverseGeocodeNamesMeaningfullyMovedPin() {
        let name = LocationSelectionPolicy.resolvedPlaceName(
            originalName: "MSC Seashore",
            reverseGeocodedName: "Port Canaveral",
            isCustomName: false,
            hasMeaningfullyMoved: true
        )

        #expect(name == "Port Canaveral")
    }

    @Test func customPlaceNameIsNeverOverwritten() {
        let name = LocationSelectionPolicy.resolvedPlaceName(
            originalName: "My Secret Spot",
            reverseGeocodedName: "Port Canaveral",
            isCustomName: true,
            hasMeaningfullyMoved: true
        )

        #expect(name == "My Secret Spot")
    }
}

struct LocationMapCameraPolicyTests {
    @Test func customNameUsesWideSpan() {
        let location = LocationData(
            coordinate: .init(latitude: 40.7, longitude: -74),
            placeName: "My Spot",
            address: nil,
            isCustomName: true
        )
        let span = LocationMapCameraPolicy.optimalSpan(for: location)
        #expect(span.latitudeDelta == 0.02)
    }

    @Test func addressWithCommaUsesTightSpan() {
        let location = LocationData(
            coordinate: .init(latitude: 40.7, longitude: -74),
            placeName: "Cafe",
            address: "123 Main, Brooklyn, NY",
            isCustomName: false
        )
        let span = LocationMapCameraPolicy.optimalSpan(for: location)
        #expect(span.latitudeDelta == 0.005)
    }

    @Test func plainPOIUsesMediumSpan() {
        let location = LocationData(
            coordinate: .init(latitude: 40.7, longitude: -74),
            placeName: "Park",
            address: "Central Park",
            isCustomName: false
        )
        let span = LocationMapCameraPolicy.optimalSpan(for: location)
        #expect(span.latitudeDelta == 0.01)
    }
}

struct LocationPlacemarkFormatterTests {
    @Test func buildsSubtitleAndAddress() {
        #expect(
            LocationPlacemarkFormatter.subtitle(city: "Brooklyn", state: "NY", title: "Title")
                == "Brooklyn, NY"
        )
        #expect(
            LocationPlacemarkFormatter.subtitle(city: nil, state: nil, title: "Title") == "Title"
        )
        #expect(
            LocationPlacemarkFormatter.address(city: "Brooklyn", state: "NY", country: "USA")
                == "Brooklyn, NY, USA"
        )
        #expect(LocationPlacemarkFormatter.address(city: nil, state: nil, country: nil) == nil)
    }

    @Test func prefersItemNameThenLocality() {
        #expect(
            LocationPlacemarkFormatter.placeName(
                itemName: "Cafe",
                city: "Brooklyn",
                state: "NY",
                country: "USA"
            ) == "Cafe"
        )
        #expect(
            LocationPlacemarkFormatter.placeName(
                itemName: nil,
                city: nil,
                state: "NY",
                country: "USA"
            ) == "NY"
        )
    }

    @Test func reverseGeocodeFallsBackToPrevious() {
        #expect(
            LocationPlacemarkFormatter.reverseGeocodedPlaceName(
                placemarkName: "  Pier  ",
                city: "Cape Canaveral",
                state: "FL",
                previousPlaceName: "Old"
            ) == "Pier"
        )
        #expect(
            LocationPlacemarkFormatter.reverseGeocodedPlaceName(
                placemarkName: "   ",
                city: "Cape Canaveral",
                state: "FL",
                previousPlaceName: "Old"
            ) == "Cape Canaveral, FL"
        )
        #expect(
            LocationPlacemarkFormatter.reverseGeocodedPlaceName(
                placemarkName: nil,
                city: nil,
                state: nil,
                previousPlaceName: "Old"
            ) == "Old"
        )
    }
}

struct CanonicalPlaceMatcherTests {
    @Test func matchesNameAndAliases() {
        #expect(CanonicalPlaceMatcher.matches(name: "Central Park", aliases: ["cp"], query: " central park "))
        #expect(CanonicalPlaceMatcher.matches(name: "Central Park", aliases: ["cp"], query: "cp"))
        #expect(!CanonicalPlaceMatcher.matches(name: "Central Park", aliases: ["cp"], query: "prospect"))
    }
}
