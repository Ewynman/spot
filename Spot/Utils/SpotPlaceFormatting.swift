import CoreLocation
import Foundation

/// Pure presentation helpers for the place metadata currently available on a `Spot`.
enum SpotPlaceFormatting {
    static let fallbackTitle = "Spot"

    static func title(for spot: Spot) -> String {
        title(from: spot.locationName)
    }

    static func title(from locationName: String?) -> String {
        normalizedOptionalText(locationName) ?? fallbackTitle
    }

    /// Returns the city/state portion when it adds information beyond the title.
    static func locality(for spot: Spot) -> String? {
        locality(from: spot.locationName, title: title(for: spot))
    }

    static func locality(from locationName: String?, title: String) -> String? {
        guard let locationName = normalizedOptionalText(locationName) else { return nil }
        let locality = normalizedOptionalText(SpotLocationDisplay.cityState(from: locationName))
        guard let locality, locality.caseInsensitiveCompare(title) != .orderedSame else {
            return nil
        }
        return locality
    }

    /// Trims and collapses whitespace, turning absent or whitespace-only copy into `nil`.
    static func geographicDescription(_ description: String?) -> String? {
        normalizedOptionalText(description, collapseWhitespace: true)
    }

    /// Best available deterministic context from today's single location string.
    /// Richer descriptions can replace this when structured place fields exist.
    static func geographicContext(for spot: Spot) -> String? {
        guard let locality = locality(for: spot) else { return nil }
        return "In \(locality)."
    }

    static func isValidCoordinate(latitude: Double?, longitude: Double?) -> Bool {
        guard let latitude, let longitude,
              latitude.isFinite, longitude.isFinite,
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            return false
        }
        return latitude != 0 || longitude != 0
    }

    static func coordinate(for spot: Spot) -> CLLocationCoordinate2D? {
        guard isValidCoordinate(latitude: spot.latitude, longitude: spot.longitude),
              let latitude = spot.latitude,
              let longitude = spot.longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func normalizedOptionalText(
        _ value: String?,
        collapseWhitespace: Bool = false
    ) -> String? {
        guard let value else { return nil }
        let normalized: String
        if collapseWhitespace {
            normalized = value
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        } else {
            normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalized.isEmpty ? nil : normalized
    }
}
