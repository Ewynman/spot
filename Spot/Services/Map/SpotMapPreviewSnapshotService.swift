import MapKit
import UIKit

enum SpotMapPreviewStyle: String, Hashable {
    case lightMutedStandard
}

/// Stable, value-based identity for an in-memory map preview.
struct SpotMapPreviewCacheKey: Hashable {
    let spotIdentifier: String
    let roundedLatitude: Int64
    let roundedLongitude: Int64
    let style: SpotMapPreviewStyle
    let regionVersion: Int
    let widthInHundredths: Int64
    let heightInHundredths: Int64
    let scaleInThousandths: Int64

    init(
        spotIdentifier: String,
        coordinate: CLLocationCoordinate2D,
        style: SpotMapPreviewStyle,
        regionVersion: Int = 1,
        size: CGSize,
        displayScale: CGFloat
    ) {
        self.spotIdentifier = spotIdentifier
        roundedLatitude = Self.quantize(coordinate.latitude, multiplier: 100_000)
        roundedLongitude = Self.quantize(coordinate.longitude, multiplier: 100_000)
        self.style = style
        self.regionVersion = regionVersion
        widthInHundredths = Self.quantize(size.width, multiplier: 100)
        heightInHundredths = Self.quantize(size.height, multiplier: 100)
        scaleInThousandths = Self.quantize(displayScale, multiplier: 1_000)
    }

    var storageKey: NSString {
        [
            spotIdentifier,
            String(roundedLatitude),
            String(roundedLongitude),
            style.rawValue,
            String(regionVersion),
            String(widthInHundredths),
            String(heightInHundredths),
            String(scaleInThousandths)
        ].joined(separator: "|") as NSString
    }

    private static func quantize<T: BinaryFloatingPoint>(
        _ value: T,
        multiplier: T
    ) -> Int64 {
        Int64((value * multiplier).rounded())
    }
}

enum SpotMapPreviewSnapshotError: Error, Equatable {
    case invalidCoordinate
    case invalidSize
    case invalidDisplayScale
}

/// Creates light, muted, POI-free map images for compact Spot previews.
///
/// The returned image contains only MapKit's snapshot. Callers can layer a
/// `SpotMarkerView` over its center without baking UI into the cached bitmap.
@MainActor
final class SpotMapPreviewSnapshotService {
    static let shared = SpotMapPreviewSnapshotService()

    static let coordinateSpan = MKCoordinateSpan(
        latitudeDelta: 0.01,
        longitudeDelta: 0.01
    )

    private let cache = NSCache<NSString, UIImage>()

    init(cacheCountLimit: Int = 80, cacheCostLimit: Int = 64 * 1_024 * 1_024) {
        cache.countLimit = cacheCountLimit
        cache.totalCostLimit = cacheCostLimit
    }

    static func region(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: coordinateSpan)
    }

    static func cacheKey(
        for spot: Spot,
        coordinate: CLLocationCoordinate2D,
        style: SpotMapPreviewStyle,
        size: CGSize,
        displayScale: CGFloat
    ) -> SpotMapPreviewCacheKey {
        SpotMapPreviewCacheKey(
            spotIdentifier: spot.id ?? "spot-without-id",
            coordinate: coordinate,
            style: style,
            size: size,
            displayScale: displayScale
        )
    }

    func snapshot(
        for spot: Spot,
        size: CGSize,
        displayScale: CGFloat,
        style: SpotMapPreviewStyle = .lightMutedStandard
    ) async throws -> UIImage {
        try Task.checkCancellation()
        guard let coordinate = SpotPlaceFormatting.coordinate(for: spot) else {
            throw SpotMapPreviewSnapshotError.invalidCoordinate
        }
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else {
            throw SpotMapPreviewSnapshotError.invalidSize
        }
        guard displayScale.isFinite, displayScale > 0 else {
            throw SpotMapPreviewSnapshotError.invalidDisplayScale
        }

        let key = Self.cacheKey(
            for: spot,
            coordinate: coordinate,
            style: style,
            size: size,
            displayScale: displayScale
        )
        if let cached = cache.object(forKey: key.storageKey) {
            return cached
        }

        let options = MKMapSnapshotter.Options()
        options.region = Self.region(center: coordinate)
        options.size = size
        options.scale = displayScale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        let configuration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        let snapshotter = MKMapSnapshotter(options: options)
        let cancellationBox = SnapshotterCancellationBox(snapshotter)
        let snapshot = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let snapshot = try await snapshotter.start()
            try Task.checkCancellation()
            return snapshot
        } onCancel: {
            cancellationBox.cancel()
        }

        let image = snapshot.image
        let pixelCost = Int(size.width * displayScale) * Int(size.height * displayScale) * 4
        cache.setObject(image, forKey: key.storageKey, cost: pixelCost)
        return image
    }
}

private final class SnapshotterCancellationBox: @unchecked Sendable {
    private let snapshotter: MKMapSnapshotter

    init(_ snapshotter: MKMapSnapshotter) {
        self.snapshotter = snapshotter
    }

    func cancel() {
        snapshotter.cancel()
    }
}
