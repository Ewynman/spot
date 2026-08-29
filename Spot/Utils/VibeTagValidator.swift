//
//  VibeTagValidator.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum VibeTagValidationResult {
    case ok(String)
    case tooShort
    case tooLong
    case blocked(String)
}

struct VibeTagValidator {
    private struct Rules: Decodable {
        let version: Int?
        let exact: [String]
        let contains: [String]
        let patterns: [String]?
        let length: Length?
        struct Length: Decodable { let min: Int?; let max: Int? }
    }

    private let rules: Rules
    private let patternRegexes: [NSRegularExpression]

    init() {
        if let url = Bundle.main.url(forResource: "BlockedTerms", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Rules.self, from: data) {
            self.rules = decoded
        } else {
            self.rules = Rules(version: 1, exact: [], contains: [], patterns: nil, length: .init(min: 2, max: 30))
        }
        self.patternRegexes = (rules.patterns ?? []).compactMap { try? NSRegularExpression(pattern: $0) }
    }

    func validate(_ raw: String) -> VibeTagValidationResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let minLen = rules.length?.min ?? 2
        let maxLen = rules.length?.max ?? 30
        if trimmed.count < minLen { return .tooShort }
        if trimmed.count > maxLen { return .tooLong }

        let norm = StringNormalizer.normalized(trimmed)
        if rules.exact.contains(norm) { return .blocked(norm) }
        if let hit = rules.contains.first(where: { norm.contains($0) }) { return .blocked(hit) }
        if patternRegexes.contains(where: { $0.firstMatch(in: norm, range: NSRange(location: 0, length: norm.utf16.count)) != nil }) {
            return .blocked("pattern")
        }
        return .ok(trimmed)
    }

}
