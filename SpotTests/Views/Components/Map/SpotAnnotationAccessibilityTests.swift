//
//  SpotAnnotationAccessibilityTests.swift
//  SpotTests
//
//  Locks down the accessible label composed for photo preview markers.
//  Photo pins are decorative from an assistive-technology perspective: the
//  image itself never conveys meaning to VoiceOver, so the annotation
//  label must always include the author + place text derived from the
//  `Spot` payload and never surface literal "nil" values.
//
//  These are pure-string assertions that run without MapKit or UIKit.
//

import Foundation
import Testing
@testable import Spot

struct SpotAnnotationAccessibilityTests {

    @Test func fullyPopulatedSpotProducesReadableLabel() {
        let spot = Spot(id: "1", username: "eddie", locationName: "West 72nd St")
        let label = SpotAnnotationAccessibility.label(for: spot)
        #expect(label == "Spot by eddie, West 72nd St. Double-tap to preview.")
    }

    @Test func missingUsernameFallsBackToSomeone() {
        let spot = Spot(id: "1", username: nil, locationName: "West 72nd St")
        let label = SpotAnnotationAccessibility.label(for: spot)
        #expect(label == "Spot by someone, West 72nd St. Double-tap to preview.")
    }

    @Test func missingLocationFallsBackToASavedSpot() {
        let spot = Spot(id: "1", username: "eddie", locationName: nil)
        let label = SpotAnnotationAccessibility.label(for: spot)
        #expect(label == "Spot by eddie, a saved spot. Double-tap to preview.")
    }

    @Test func whitespaceUsernameAndLocationDegradeGracefully() {
        let spot = Spot(id: "1", username: "   ", locationName: "\n")
        let label = SpotAnnotationAccessibility.label(for: spot)
        #expect(label == "Spot by someone, a saved spot. Double-tap to preview.")
    }
}
