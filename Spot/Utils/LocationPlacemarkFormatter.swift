import Foundation

/// Formats MapKit / CLPlacemark fields into display strings and LocationData inputs.
enum LocationPlacemarkFormatter {
    /// City/state subtitle for search rows (falls back to title).
    static func subtitle(city: String?, state: String?, title: String?) -> String? {
        let parts = [city, state].compactMap { $0 }
        if parts.isEmpty { return title }
        return parts.joined(separator: ", ")
    }

    /// Full address line: city, state, country.
    static func address(city: String?, state: String?, country: String?) -> String? {
        let parts = [city, state, country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Prefer map item name, then city/state/country, then fallback.
    static func placeName(
        itemName: String?,
        city: String?,
        state: String?,
        country: String?,
        fallback: String = "Unknown Location"
    ) -> String {
        itemName ?? (city ?? state ?? country ?? fallback)
    }

    /// Reverse-geocode display name: prefer placemark name, else city/state, else previous.
    static func reverseGeocodedPlaceName(
        placemarkName: String?,
        city: String?,
        state: String?,
        previousPlaceName: String
    ) -> String {
        let name = placemarkName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityTrimmed = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateTrimmed = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityState = [cityTrimmed, stateTrimmed].compactMap { $0 }.joined(separator: ", ")
        if let name, !name.isEmpty { return name }
        return cityState.isEmpty ? previousPlaceName : cityState
    }
}

/// Exact name/alias matching for bundled canonical places.
enum CanonicalPlaceMatcher {
    static func matches(name: String, aliases: [String], query: String) -> Bool {
        let s = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased() == s { return true }
        return aliases.contains(s)
    }
}
