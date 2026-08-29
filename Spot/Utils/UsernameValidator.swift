//
//  UsernameValidator.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum UsernameValidationResult {
    case ok
    case tooShort
    case tooLong
    case invalidChars
    case reserved
    case blocked(String)
}

struct UsernameValidator {
    private struct Rules: Decodable {
        let version: Int?
        let reserved: [String]
        let exact: [String]
        let contains: [String]
        let patterns: [String]?
        let length: Length?
        let charset: Charset?
        struct Length: Decodable { let min: Int?; let max: Int? }
        struct Charset: Decodable {
            let allowRegex: String?
            let disallowLeading: [String]?
            let disallowTrailing: [String]?
            let disallowConsecutive: [String]?
        }
    }

    private let rules: Rules
    private let allowRegex: NSRegularExpression?
    private let patternRegexes: [NSRegularExpression]

    init() {
        if let url = Bundle.main.url(forResource: "BlockedTerms", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Rules.self, from: data) {
            self.rules = decoded
        } else {
            self.rules = Rules(
                version: 1,
                reserved: ["admin", "support", "moderator", "spot", "owner"],
                exact: [],
                contains: [],
                patterns: nil,
                length: .init(min: 3, max: 20),
                charset: .init(
                    allowRegex: "^[A-Za-z0-9._-]+$",
                    disallowLeading: [".", "_", "-"],
                    disallowTrailing: [".", "_", "-"],
                    disallowConsecutive: ["..", "__", "--", "._", "_.", "-.", ".-", "_-", "-_"]
                )
            )
        }
        if let r = rules.charset?.allowRegex {
            self.allowRegex = try? NSRegularExpression(pattern: r)
        } else {
            self.allowRegex = nil
        }
        self.patternRegexes = (rules.patterns ?? []).compactMap { try? NSRegularExpression(pattern: $0) }
    }

    func validate(_ raw: String) -> UsernameValidationResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let minLen = rules.length?.min ?? 3
        let maxLen = rules.length?.max ?? 20
        if trimmed.count < minLen { return .tooShort }
        if trimmed.count > maxLen { return .tooLong }

        // Basic charset/structure checks on raw
        if let re = allowRegex, re.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) == nil {
            return .invalidChars
        }
        if let leading = rules.charset?.disallowLeading, leading.contains(where: { trimmed.hasPrefix($0) }) { return .invalidChars }
        if let trailing = rules.charset?.disallowTrailing, trailing.contains(where: { trimmed.hasSuffix($0) }) { return .invalidChars }
        if let consec = rules.charset?.disallowConsecutive, consec.contains(where: { trimmed.contains($0) }) { return .invalidChars }

        // Normalize and check blocklists
        let norm = normalized(trimmed)
        if rules.reserved.contains(norm) { return .reserved }
        if rules.exact.contains(norm) { return .blocked(norm) }
        if let term = rules.contains.first(where: { norm.contains($0) }) { return .blocked(term) }
        // Patterns
        if patternRegexes.contains(where: { $0.firstMatch(in: norm, range: NSRange(location: 0, length: norm.utf16.count)) != nil }) {
            return .blocked("pattern")
        }
        // Also check reversed
        let rev = String(norm.reversed())
        if rules.exact.contains(rev) { return .blocked("reverse_exact") }
        if let term = rules.contains.first(where: { rev.contains($0) }) { return .blocked("reverse_contains:\(term)") }
        return .ok
    }

    func normalized(_ raw: String) -> String {
        var s = raw.lowercased()
        // NFKD + remove diacritics
        s = s.applyingTransform(.init("NFKD"), reverse: false) ?? s
        s = s.unicodeScalars.filter { !$0.properties.isDiacritic }.map(String.init).joined()
        // Map leet
        let map: [Character: Character] = [
            "0": "o", "1": "i", "2": "z", "3": "e", "4": "a", "5": "s", "6": "g", "7": "t", "8": "b", "9": "g",
            "$": "s", "@": "a"
        ]
        s = String(s.map { map[$0] ?? $0 })
        // Remove separators/punctuation/whitespace (keep only a-z0-9)
        s = s.replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
        // Collapse repeats
        var out = ""
        var last: Character?
        for ch in s {
            if ch == last { continue }
            out.append(ch); last = ch
        }
        return out
    }
}
