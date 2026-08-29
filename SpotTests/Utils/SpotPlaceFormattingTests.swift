//
//  SpotPlaceFormattingTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Testing
@testable import Spot

struct SpotPlaceFormattingTests {
    @Test func titleTrimsLocationName() {
        let spot = Spot(locationName: "  The Met Cloisters \n")

        #expect(SpotPlaceFormatting.title(for: spot) == "The Met Cloisters")
    }

    @Test func titleFallsBackOnlyForAbsentContent() {
        #expect(SpotPlaceFormatting.title(from: nil) == "Spot")
        #expect(SpotPlaceFormatting.title(from: " \n\t ") == "Spot")
        #expect(SpotPlaceFormatting.title(from: "Spot Coffee") == "Spot Coffee")
    }

    @Test func localityUsesCityStateWhenDistinctFromTitle() {
        let spot = Spot(locationName: "Blue Bottle Coffee, Brooklyn, NY, United States")

        #expect(SpotPlaceFormatting.locality(for: spot) == "Brooklyn, NY")
    }

    @Test func localityIsOmittedWhenItRepeatsTitle() {
        let spot = Spot(locationName: "Brooklyn, NY")

        #expect(SpotPlaceFormatting.locality(for: spot) == nil)
    }

    @Test func geographicDescriptionNormalizesOptionalWhitespace() {
        #expect(SpotPlaceFormatting.geographicDescription(nil) == nil)
        #expect(SpotPlaceFormatting.geographicDescription(" \n ") == nil)
        #expect(
            SpotPlaceFormatting.geographicDescription("  Near the river\nwith skyline views  ")
                == "Near the river with skyline views"
        )
    }

    @Test func geographicContextUsesStructuredLocalityOrOmitsCleanly() {
        #expect(
            SpotPlaceFormatting.geographicContext(
                for: Spot(locationName: "Blue Bottle Coffee, Brooklyn, NY, United States")
            ) == "In Brooklyn, NY."
        )
        #expect(
            SpotPlaceFormatting.geographicContext(for: Spot(locationName: "Brooklyn, NY")) == nil
        )
    }

    @Test func formattingPreservesUnicodeNames() {
        let spot = Spot(locationName: "Waimea Bay, Haleʻiwa, Hawaiʻi")
        #expect(SpotPlaceFormatting.title(for: spot) == "Waimea Bay, Haleʻiwa, Hawaiʻi")
        #expect(SpotPlaceFormatting.locality(for: spot) == "Haleʻiwa, Hawaiʻi")
    }

    @Test func acceptsFiniteInRangeCoordinatesExceptNullIsland() {
        #expect(SpotPlaceFormatting.isValidCoordinate(latitude: 90, longitude: 180))
        #expect(SpotPlaceFormatting.isValidCoordinate(latitude: -90, longitude: -180))
        #expect(SpotPlaceFormatting.isValidCoordinate(latitude: 0, longitude: 12.5))
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: 0, longitude: 0))
    }

    @Test func rejectsMissingNonFiniteAndOutOfRangeCoordinates() {
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: nil, longitude: 1))
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: 1, longitude: nil))
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: .nan, longitude: 1))
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: 1, longitude: .infinity))
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: 90.0001, longitude: 0))
        #expect(!SpotPlaceFormatting.isValidCoordinate(latitude: 0, longitude: -180.0001))
    }

    @Test func coordinateReturnsOnlyValidatedValues() {
        let valid = Spot(latitude: 40.7128, longitude: -74.0060)
        let invalid = Spot(latitude: 0, longitude: 0)

        #expect(SpotPlaceFormatting.coordinate(for: valid)?.latitude == 40.7128)
        #expect(SpotPlaceFormatting.coordinate(for: valid)?.longitude == -74.0060)
        #expect(SpotPlaceFormatting.coordinate(for: invalid) == nil)
    }
}
