//
//  StringNormalizer.swift
//  Spot
//
//  Created by Edward Wynman on 1/12/26.
//

import Foundation

struct StringNormalizer {
    static func normalized(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.applyingTransform(.init("NFKD"), reverse: false) ?? s
        s = s.unicodeScalars.filter { !$0.properties.isDiacritic }.map(String.init).joined()
        let map: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "$": "s", "@": "a"]
        s = String(s.map { map[$0] ?? $0 })
        s = s.replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
        var out = ""
        var last: Character?
        for ch in s { if ch == last { continue }; out.append(ch); last = ch }
        return out
    }
}
