import CoreGraphics
import MapKit
import Testing
@testable import Spot

@MainActor
struct SpotMapPreviewSnapshotServiceTests {
    @Test func previewRegionUsesDeterministicSpan() {
        let center = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

        let region = SpotMapPreviewSnapshotService.region(center: center)

        #expect(region.center.latitude == center.latitude)
        #expect(region.center.longitude == center.longitude)
        #expect(region.span.latitudeDelta == 0.01)
        #expect(region.span.longitudeDelta == 0.01)
    }

    @Test func cacheKeyRoundsCoordinatesToFiveDecimalPlaces() {
        let spot = Spot(id: "spot-1")
        let size = CGSize(width: 320, height: 180)
        let first = SpotMapPreviewSnapshotService.cacheKey(
            for: spot,
            coordinate: CLLocationCoordinate2D(
                latitude: 40.712801,
                longitude: -74.006001
            ),
            style: .lightMutedStandard,
            size: size,
            displayScale: 3
        )
        let second = SpotMapPreviewSnapshotService.cacheKey(
            for: spot,
            coordinate: CLLocationCoordinate2D(
                latitude: 40.712804,
                longitude: -74.006004
            ),
            style: .lightMutedStandard,
            size: size,
            displayScale: 3
        )

        #expect(first == second)
    }

    @Test func cacheKeyIncludesSpotSizeAndDisplayScale() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let base = SpotMapPreviewSnapshotService.cacheKey(
            for: Spot(id: "spot-1"),
            coordinate: coordinate,
            style: .lightMutedStandard,
            size: CGSize(width: 320, height: 180),
            displayScale: 2
        )
        let otherSpot = SpotMapPreviewSnapshotService.cacheKey(
            for: Spot(id: "spot-2"),
            coordinate: coordinate,
            style: .lightMutedStandard,
            size: CGSize(width: 320, height: 180),
            displayScale: 2
        )
        let otherSize = SpotMapPreviewSnapshotService.cacheKey(
            for: Spot(id: "spot-1"),
            coordinate: coordinate,
            style: .lightMutedStandard,
            size: CGSize(width: 321, height: 180),
            displayScale: 2
        )
        let otherScale = SpotMapPreviewSnapshotService.cacheKey(
            for: Spot(id: "spot-1"),
            coordinate: coordinate,
            style: .lightMutedStandard,
            size: CGSize(width: 320, height: 180),
            displayScale: 3
        )

        #expect(base != otherSpot)
        #expect(base != otherSize)
        #expect(base != otherScale)
    }

    @Test func storageKeyIsStableForEquivalentValues() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let first = SpotMapPreviewCacheKey(
            spotIdentifier: "spot-1",
            coordinate: coordinate,
            style: .lightMutedStandard,
            size: CGSize(width: 300, height: 200),
            displayScale: 2
        )
        let second = SpotMapPreviewCacheKey(
            spotIdentifier: "spot-1",
            coordinate: coordinate,
            style: .lightMutedStandard,
            size: CGSize(width: 300, height: 200),
            displayScale: 2
        )

        #expect(first.storageKey == second.storageKey)
    }
}
