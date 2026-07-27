//
//  MapUserLocationMarkerTests.swift
//  SpotTests
//

import Testing
@testable import Spot

struct MapUserLocationMarkerTests {

    @Test func missingUsernameUsesPersonFallback() {
        #expect(UserLocationAnnotationView.fallbackContent(from: nil) == .personSymbol)
        #expect(UserLocationAnnotationView.fallbackContent(from: "") == .personSymbol)
        #expect(UserLocationAnnotationView.fallbackContent(from: "   ") == .personSymbol)
    }

    @Test func usernameUsesInitialsFallback() {
        #expect(UserLocationAnnotationView.fallbackContent(from: "eddie") == .initials("E"))
        #expect(UserLocationAnnotationView.fallbackContent(from: "Eddie Wynman") == .initials("EW"))
        #expect(UserLocationAnnotationView.fallbackContent(from: "spot_user") == .initials("SU"))
    }

    @Test func punctuationOnlyUsernameUsesPersonFallback() {
        #expect(UserLocationAnnotationView.fallbackContent(from: "---") == .personSymbol)
    }
}
