import Foundation
import Testing
@testable import Spot

struct SpotLocationDisplayTests {
    @Test func dropsCountryAndStreetDigits() {
        #expect(
            SpotLocationDisplay.cityState(from: "123 Main St, Brooklyn, NY, United States")
                == "Brooklyn, NY"
        )
    }

    @Test func returnsSingleSegmentWhenOnlyOneRemains() {
        #expect(SpotLocationDisplay.cityState(from: "Brooklyn") == "Brooklyn")
    }

    @Test func fallsBackToRawWhenEverythingFiltered() {
        #expect(SpotLocationDisplay.cityState(from: "90210") == "90210")
    }
}

struct MapDrawerDismissRestoreTests {
    @Test func mapMovedDoesNotRestoreViewport() {
        #expect(MapDrawerDismissRestore.shouldRestoreViewport(after: .mapMoved) == false)
    }

    @Test func closeButtonRestoresViewport() {
        #expect(MapDrawerDismissRestore.shouldRestoreViewport(after: .closeButton) == true)
        #expect(MapDrawerDismissRestore.shouldRestoreViewport(after: .emptyMapTap) == true)
        #expect(MapDrawerDismissRestore.shouldRestoreViewport(after: .filterChanged) == true)
    }
}
