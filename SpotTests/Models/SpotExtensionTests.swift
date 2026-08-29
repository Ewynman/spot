//
//  SpotExtensionTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 3/2/25.
//

import Testing
@testable import Spot

struct SpotExtensionTests {

    @Test func safeIdWithId() {
        let spot = Spot(id: "spot123", userId: nil)
        #expect(spot.safeId == "spot123")
    }

    @Test func safeIdWithoutId() {
        let spot = Spot(id: nil, userId: nil)
        #expect(spot.safeId == "nil")
    }
}
