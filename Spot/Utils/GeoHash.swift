//
//  GeoHash.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum GeoHash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int = 7) -> String {
        var latInterval = (-90.0, 90.0)
        var lonInterval = (-180.0, 180.0)
        var hash: [Character] = []

        var isEven = true
        var bit = 0
        var ch = 0

        while hash.count < max(1, precision) {
            if isEven {
                let mid = (lonInterval.0 + lonInterval.1) / 2
                if longitude > mid { ch = (ch << 1) | 1; lonInterval.0 = mid } else { ch = (ch << 1); lonInterval.1 = mid }
            } else {
                let mid = (latInterval.0 + latInterval.1) / 2
                if latitude > mid { ch = (ch << 1) | 1; latInterval.0 = mid } else { ch = (ch << 1); latInterval.1 = mid }
            }

            isEven.toggle()
            bit += 1

            if bit == 5 {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return String(hash)
    }

    static func neighbors(of hash: String) -> [String] {
        // Return 8 neighboring prefixes of same precision
        guard !hash.isEmpty else { return [] }
        // A quick approximation: vary last char within +/-1 on base32 ring where possible
        let alphabet = base32
        let map = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) })
        var results: [String] = []
        let chars = Array(hash)
        for delta in [-1, 1] {
            if let idx = map[chars.last ?? "0"] {
                let n = max(0, min(alphabet.count - 1, idx + delta))
                var c = chars
                c[c.count - 1] = alphabet[n]
                results.append(String(c))
            }
        }
        // crude set of 8: change last and second last to approximate grid
        if chars.count >= 2 {
            for d1 in [-1, 1] { for d2 in [-1, 1] {
                var c = chars
                if let idx = map[c.last ?? "0"] { c[c.count - 1] = alphabet[max(0, min(alphabet.count-1, idx + d1))] }
                if let idx2 = map[c[c.count - 2]] { c[c.count - 2] = alphabet[max(0, min(alphabet.count-1, idx2 + d2))] }
                results.append(String(c))
            }}
        }
        return Array(Set(results)).filter { !$0.isEmpty }
    }

    static func endRange(for prefix: String) -> String {
        // Next ASCII after 'z' trick to build upper bound; using '~' ensures it sorts after any base32 char
        return prefix + "~"
    }
}
