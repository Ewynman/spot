import Foundation
import MapKit

/// Camera zoom heuristics for the post-flow location map.
enum LocationMapCameraPolicy {
    static func optimalSpan(for location: LocationData) -> MKCoordinateSpan {
        if location.isCustomName {
            return MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        } else if location.address?.contains(",") == true {
            return MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        } else {
            return MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }
}
