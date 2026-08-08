import CoreLocation

/// Pure policies for post-flow location pin movement and name resolution.
enum LocationSelectionPolicy {
    static let meaningfulMoveMeters: CLLocationDistance = 20

    static func hasMeaningfullyMoved(
        from initial: CLLocationCoordinate2D,
        to candidate: CLLocationCoordinate2D
    ) -> Bool {
        let start = CLLocation(latitude: initial.latitude, longitude: initial.longitude)
        let end = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
        return start.distance(from: end) >= meaningfulMoveMeters
    }

    static func resolvedPlaceName(
        originalName: String,
        reverseGeocodedName: String,
        isCustomName: Bool,
        hasMeaningfullyMoved: Bool
    ) -> String {
        guard !isCustomName, hasMeaningfullyMoved else { return originalName }
        let candidate = reverseGeocodedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? originalName : candidate
    }
}
