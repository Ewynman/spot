//
//  SpotExtensionTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
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
