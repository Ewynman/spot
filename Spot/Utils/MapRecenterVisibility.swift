//
//  MapRecenterVisibility.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreLocation

/// Whether the map recenter control should be visible for a permission + fix combo.
enum MapRecenterVisibility {
    static func shouldShow(status: CLAuthorizationStatus, hasLocation: Bool) -> Bool {
        switch status {
        case .denied, .restricted:
            return hasLocation
        case .notDetermined:
            return true
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        @unknown default:
            return hasLocation
        }
    }
}
