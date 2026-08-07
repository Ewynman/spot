import CoreLocation
import MapKit

enum LocationSearchPolicy {
    static let nearbyRadiusMeters: CLLocationDistance = 3_000
    static let expandedNearbyRadiusMeters: CLLocationDistance = 8_000
    static let localSearchRadiusMeters: CLLocationDistance = 50_000
    static let nearbyRefreshThresholdMeters: CLLocationDistance = 250
    static let maximumNearbyResults = 30
    static let maximumSearchResults = 30

    /// Whether the user moved far enough to warrant re-querying nearby places.
    static func shouldRefreshNearby(
        from previous: CLLocation?,
        to candidate: CLLocation,
        thresholdMeters: CLLocationDistance = nearbyRefreshThresholdMeters
    ) -> Bool {
        guard let previous else { return true }
        return previous.distance(from: candidate) > thresholdMeters
    }

    static func sortedByDistance(
        _ items: [MKMapItem],
        from origin: CLLocation,
        limit: Int
    ) -> [MKMapItem] {
        items
            .compactMap { item -> (item: MKMapItem, distance: CLLocationDistance)? in
                guard let location = item.placemark.location else { return nil }
                return (item, location.distance(from: origin))
            }
            .sorted { lhs, rhs in
                if lhs.distance == rhs.distance {
                    return (lhs.item.name ?? "") < (rhs.item.name ?? "")
                }
                return lhs.distance < rhs.distance
            }
            .prefix(limit)
            .map(\.item)
    }

    static func distanceText(for item: MKMapItem, from origin: CLLocation?) -> String? {
        guard let origin, let location = item.placemark.location else { return nil }
        let distance = location.distance(from: origin)

        if distance < 1_000 {
            return "\(Int((distance / 10).rounded() * 10)) m"
        }
        return String(format: "%.1f km", distance / 1_000)
    }

    static func localSearchRegion(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: localSearchRadiusMeters,
            longitudinalMeters: localSearchRadiusMeters
        )
    }
}
