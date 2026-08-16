//
//  MapFocusCoordinator.swift
//  Spot
//
//  Internal routing bridge for opening a Spot on the main Map tab.
//

import CoreLocation
import Combine
import Foundation

enum MapFocusSource: String, Sendable {
    case homeSpotCard = "home_spot_card"
}

struct MapFocusRequest: Identifiable, Equatable {
    let id: UUID
    let spotID: String
    let coordinate: CLLocationCoordinate2D
    let spot: Spot
    let source: MapFocusSource

    init(
        id: UUID = UUID(),
        spotID: String,
        coordinate: CLLocationCoordinate2D,
        spot: Spot,
        source: MapFocusSource
    ) {
        self.id = id
        self.spotID = spotID
        self.coordinate = coordinate
        self.spot = spot
        self.source = source
    }

    static func == (lhs: MapFocusRequest, rhs: MapFocusRequest) -> Bool {
        lhs.id == rhs.id
            && lhs.spotID == rhs.spotID
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.spot == rhs.spot
            && lhs.source == rhs.source
    }
}

@MainActor
final class MapFocusCoordinator: ObservableObject {
    static let shared = MapFocusCoordinator()

    @Published private(set) var pendingRequest: MapFocusRequest?
    /// One-shot Home restore after Open in Map. Flip alone never sets this.
    @Published private(set) var pendingHomeReturnSpotID: String?
    private(set) var pendingHomeReturnSpot: Spot?

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    @discardableResult
    func requestFocus(
        on spot: Spot,
        coordinate: CLLocationCoordinate2D,
        source: MapFocusSource
    ) -> Bool {
        guard let spotID = spot.id,
              CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite,
              SpotPlaceFormatting.isValidCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
              ) else {
            return false
        }

        pendingRequest = MapFocusRequest(
            spotID: spotID,
            coordinate: coordinate,
            spot: spot,
            source: source
        )
        if source == .homeSpotCard {
            pendingHomeReturnSpotID = spotID
            pendingHomeReturnSpot = spot
        }
        notificationCenter.post(
            name: .selectMainTab,
            object: nil,
            userInfo: [SpotMainTabNotification.userInfoTabIndexKey: 1]
        )
        return true
    }

    @discardableResult
    func requestFocus(on spot: Spot, source: MapFocusSource) -> Bool {
        guard let coordinate = SpotPlaceFormatting.coordinate(for: spot) else {
            return false
        }
        return requestFocus(
            on: spot,
            coordinate: coordinate,
            source: source
        )
    }

    /// Consumes only the request a caller observed. A newer request remains pending.
    func consumePending(id expectedID: UUID? = nil) -> MapFocusRequest? {
        guard let pendingRequest else { return nil }
        if let expectedID, pendingRequest.id != expectedID {
            return nil
        }
        self.pendingRequest = nil
        return pendingRequest
    }

    /// Returns and clears the Home return target. Call only when about to scroll.
    @discardableResult
    func consumeHomeReturn() -> (spotID: String, spot: Spot?)? {
        guard let spotID = pendingHomeReturnSpotID else { return nil }
        let snapshot = pendingHomeReturnSpot
        pendingHomeReturnSpotID = nil
        pendingHomeReturnSpot = nil
        return (spotID, snapshot)
    }

    /// Peek without consuming — used to decide whether to insert a missing row.
    func peekHomeReturn() -> (spotID: String, spot: Spot?)? {
        guard let spotID = pendingHomeReturnSpotID else { return nil }
        return (spotID, pendingHomeReturnSpot)
    }
}
