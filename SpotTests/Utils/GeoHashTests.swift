//
//  GeoHashTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct GeoHashTests {

    @Test func encodeReturnsCorrectHash() {
        let hash = GeoHash.encode(latitude: 37.7749, longitude: -122.4194, precision: 7)
        #expect(!hash.isEmpty)
        #expect(hash.count == 7)
        #expect(hash.allSatisfy { "0123456789bcdefghjkmnpqrstuvwxyz".contains($0) })
    }

    @Test func encodeWithPrecision1() {
        let hash = GeoHash.encode(latitude: 0, longitude: 0, precision: 1)
        #expect(hash.count == 1)
    }

    @Test func encodeSameCoordsSameHash() {
        let h1 = GeoHash.encode(latitude: 40.7, longitude: -74.0, precision: 5)
        let h2 = GeoHash.encode(latitude: 40.7, longitude: -74.0, precision: 5)
        #expect(h1 == h2)
    }

    @Test func neighborsEmptyReturnsEmpty() {
        let result = GeoHash.neighbors(of: "")
        #expect(result.isEmpty)
    }

    @Test func neighborsSingleCharReturnsAdjacent() {
        let result = GeoHash.neighbors(of: "u")
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { !$0.isEmpty })
    }

    @Test func neighborsMultiCharReturns8Variants() {
        let hash = "ezjmg"
        let result = GeoHash.neighbors(of: hash)
        #expect(!result.isEmpty)
        #expect(Set(result).count == result.count)
    }

    @Test func endRangeReturnsPrefixWithTilde() {
        let result = GeoHash.endRange(for: "abc123")
        #expect(result == "abc123~")
    }

    @Test func endRangeEmptyPrefix() {
        let result = GeoHash.endRange(for: "")
        #expect(result == "~")
    }
}
