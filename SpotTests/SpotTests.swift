//
//  SpotTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 3/2/25.
//

import Testing
@testable import Spot

/// Root test suite - individual logic tests live in GeoHashTests, StringNormalizerTests, etc.
struct SpotTests {

    @Test func spotModuleLoads() {
        #expect(GeoHash.encode(latitude: 0, longitude: 0, precision: 1).count == 1)
    }
}
