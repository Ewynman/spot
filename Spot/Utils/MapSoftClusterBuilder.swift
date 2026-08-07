import CoreLocation
import MapKit

/// Vertical camera lift so a pin stays visible above the map drawer.
enum MapCameraLift {
    static func liftedCoordinate(
        for coord: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        mapHeight: CGFloat,
        liftPoints: CGFloat
    ) -> CLLocationCoordinate2D {
        guard mapHeight > 0, liftPoints > 0 else { return coord }
        let latPerPoint = span.latitudeDelta / Double(mapHeight)
        return CLLocationCoordinate2D(
            latitude: coord.latitude - latPerPoint * Double(liftPoints),
            longitude: coord.longitude
        )
    }
}

/// Soft clustering for far-zoom map pins.
enum MapSoftClusterBuilder {
    struct Entry: Equatable {
        /// Index into the input coordinates array for the representative pin/spot.
        let representativeIndex: Int
        let latitude: Double
        let longitude: Double
        let isCluster: Bool
        /// Input indices of all members when `isCluster` is true.
        let memberIndexes: [Int]
    }

    static func build(
        coordinates: [(id: String?, latitude: Double, longitude: Double)],
        pinCap: Int,
        bucketSize: Double = 0.05
    ) -> [Entry] {
        if coordinates.count <= pinCap {
            return coordinates.enumerated().map { index, coord in
                Entry(
                    representativeIndex: index,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    isCluster: false,
                    memberIndexes: []
                )
            }
        }

        var buckets: [String: [(index: Int, id: String?, latitude: Double, longitude: Double)]] = [:]
        for (index, entry) in coordinates.enumerated() {
            let key = String(
                format: "%.2f,%.2f",
                (entry.latitude / bucketSize).rounded() * bucketSize,
                (entry.longitude / bucketSize).rounded() * bucketSize
            )
            buckets[key, default: []].append((index, entry.id, entry.latitude, entry.longitude))
        }

        var output: [Entry] = []
        for (_, members) in buckets {
            if members.count == 1 {
                let only = members[0]
                output.append(
                    Entry(
                        representativeIndex: only.index,
                        latitude: only.latitude,
                        longitude: only.longitude,
                        isCluster: false,
                        memberIndexes: []
                    )
                )
            } else {
                let lat = members.map(\.latitude).reduce(0, +) / Double(members.count)
                let lon = members.map(\.longitude).reduce(0, +) / Double(members.count)
                output.append(
                    Entry(
                        representativeIndex: members[0].index,
                        latitude: lat,
                        longitude: lon,
                        isCluster: true,
                        memberIndexes: members.map(\.index)
                    )
                )
            }
        }
        return output
    }
}
