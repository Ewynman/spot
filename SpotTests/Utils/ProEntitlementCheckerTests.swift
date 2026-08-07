//
//  ProEntitlementCheckerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/24/2025
//

import Foundation
import Testing
@testable import Spot

struct ProEntitlementCheckerTests {

    @Test func grantsProWhenProductIDMatches() {
        let checker = ProEntitlementChecker(proProductIDs: SpotProProducts.all)
        #expect(checker.grantsPro(forProductID: "spotPro"))
    }

    @Test func deniesLegacyProductID() {
        let checker = ProEntitlementChecker(proProductIDs: SpotProProducts.all)
        #expect(!checker.grantsPro(forProductID: "spot.pro.yearly"))
    }

    @Test func deniesProForUnknownProductID() {
        let checker = ProEntitlementChecker(proProductIDs: ["spotPro"])
        #expect(!checker.grantsPro(forProductID: "other.product"))
    }

    @Test func emptyProductSetNeverGrantsPro() {
        let checker = ProEntitlementChecker(proProductIDs: [String]())
        #expect(!checker.grantsPro(forProductID: "spotPro"))
    }
}
