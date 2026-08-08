import Foundation

/// Formats a place string down to city/state for SpotCard chrome.
enum SpotLocationDisplay {
    private static let disallowed = Set([
        "united states", "usa", "us", "united states of america"
    ])

    static func cityState(from raw: String) -> String {
        let parts = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { segment in
                let lower = segment.lowercased()
                if disallowed.contains(lower) { return false }
                return segment.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil
            }

        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ", ")
        } else if let first = parts.first {
            return first
        } else {
            return raw
        }
    }
}
