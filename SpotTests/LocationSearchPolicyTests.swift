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
