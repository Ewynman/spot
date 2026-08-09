import CoreLocation
import Foundation
import MapKit
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

struct SpotGridLayoutTests {
    @Test func computesTwoColumnWidth() {
        // 390 - 24 padding - 12 spacing = 354 / 2 = 177
        #expect(SpotGridLayout.itemWidth(columns: 2, containerWidth: 390) == 177)
    }

    @Test func singleColumnUsesFullContentWidth() {
        #expect(SpotGridLayout.itemWidth(columns: 1, containerWidth: 390) == 366)
    }
}

struct SpotMenuPlacementTests {
    @Test func anchorsMenuToTappedButtonInsteadOfCardEdge() {
        let center = SpotMenuPlacement.center(
            buttonFrame: CGRect(x: 92, y: 520, width: 24, height: 24),
            menuSize: CGSize(width: 170, height: 220),
            containerSize: CGSize(width: 390, height: 600)
        )

        #expect(center.x == 104)
        #expect(center.y < 520)
    }

    @Test func clampsMenuInsideHorizontalCardBounds() {
        let center = SpotMenuPlacement.center(
            buttonFrame: CGRect(x: 378, y: 40, width: 24, height: 24),
            menuSize: CGSize(width: 170, height: 100),
            containerSize: CGSize(width: 390, height: 600)
        )

        #expect(center.x == 297)
        #expect(center.y > 64)
    }

    @Test func placesMenuNearInteractionBarNotTopLeadingOrigin() {
        // Typical feed card: ⋮ sits under the media, not at the card origin.
        let buttonFrame = CGRect(x: 72, y: 480, width: 24, height: 24)
        let center = SpotMenuPlacement.center(
            buttonFrame: buttonFrame,
            menuSize: CGSize(width: 170, height: 180),
            containerSize: CGSize(width: 390, height: 640)
        )

        #expect(center.x > 80)
        #expect(center.y > 300)
        #expect(abs(center.x - buttonFrame.midX) < 1 || center.x >= 93)
    }
}

struct SpotMapFilterStateTransitionTests {
    @Test func togglingDimensionOnAndOff() {
        var state = SpotMapFilterState.empty
        let openPicker = state.toggling(.vibe)
        #expect(openPicker)
        #expect(state.dimensions.contains(.vibe))

        state.vibeTags = ["Chill"]
        let reopen = state.toggling(.vibe)
        #expect(!reopen)
        #expect(!state.dimensions.contains(.vibe))
        #expect(state.vibeTags.isEmpty)
    }

    @Test func togglingVibeTagEnablesDimension() {
        var state = SpotMapFilterState.empty
        state.togglingVibeTag("Cozy")
        #expect(state.vibeTags.contains("Cozy"))
        #expect(state.dimensions.contains(.vibe))
        state.togglingVibeTag("Cozy")
        #expect(!state.vibeTags.contains("Cozy"))
    }
}

struct MapDrawerLayoutPolicyTests {
    @Test func expandsAndCapsBelowPills() {
        let expanded = MapDrawerLayoutPolicy.expandedHeight(
            screenHeight: 800,
            bottomSafeArea: 34,
            maxScreenFraction: 0.7,
            minHeight: 120
        )
        #expect(expanded == 560) // 800 * 0.7

        let ceiling = MapDrawerLayoutPolicy.maxHeightBelowFilterPills(
            screenHeight: 800,
            bottomPadding: 34,
            pillsBottomY: 100,
            gap: 12
        )
        #expect(ceiling == 654)

        #expect(MapDrawerLayoutPolicy.filterPillsBottomY(measuredMaxY: nil, safeAreaTop: 47) == 99)
        #expect(MapDrawerLayoutPolicy.resolvedHeight(requested: 500, ceiling: 300, minHeight: 120) == 300)
    }
}

struct MapCameraLiftTests {
    @Test func liftsLatitudeWhenHeightPositive() {
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        let coord = CLLocationCoordinate2D(latitude: 40, longitude: -74)
        let lifted = MapCameraLift.liftedCoordinate(for: coord, span: span, mapHeight: 100, liftPoints: 50)
        #expect(lifted.latitude < coord.latitude)
        #expect(lifted.longitude == coord.longitude)
    }

    @Test func noLiftWhenZeroHeight() {
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        let coord = CLLocationCoordinate2D(latitude: 40, longitude: -74)
        let lifted = MapCameraLift.liftedCoordinate(for: coord, span: span, mapHeight: 0, liftPoints: 50)
        #expect(lifted.latitude == coord.latitude)
    }
}

struct MapSoftClusterBuilderTests {
    @Test func underCapKeepsIndividuals() {
        let coords = (0..<3).map { (id: "\($0)", latitude: Double($0), longitude: 0.0) }
        let built = MapSoftClusterBuilder.build(coordinates: coords, pinCap: 5)
        #expect(built.count == 3)
        #expect(built.allSatisfy { !$0.isCluster })
    }

    @Test func overCapBucketsNearbyPoints() {
        let coords: [(id: String?, latitude: Double, longitude: Double)] = [
            ("a", 40.00, -74.00),
            ("b", 40.01, -74.01),
            ("c", 41.00, -73.00),
            ("d", 41.01, -73.01),
            ("e", 42.00, -72.00),
            ("f", 42.01, -72.01),
        ]
        let built = MapSoftClusterBuilder.build(coordinates: coords, pinCap: 2)
        let hasCluster = built.contains { $0.isCluster }
        #expect(hasCluster)
        #expect(built.count < coords.count)
    }
}
