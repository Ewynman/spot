//
//  MapFocusCoordinatorTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Spot

@MainActor
@Suite("Map focus coordinator")
struct MapFocusCoordinatorTests {

    @Test("Focus request is retained and selects the Map tab")
    func requestIsRetainedAndSelectsMapTab() {
        let center = NotificationCenter()
        let coordinator = MapFocusCoordinator(notificationCenter: center)
        let capture = NotificationCapture()
        let observer = center.addObserver(
            forName: .selectMainTab,
            object: nil,
            queue: nil
        ) { notification in
            capture.tabIndex = notification.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int
        }
        defer { center.removeObserver(observer) }

        let spot = SpotTestHelpers.makeSpot(
            id: "spot-1",
            latitude: 25.7617,
            longitude: -80.1918
        )
        let routed = coordinator.requestFocus(on: spot, source: .homeSpotCard)

        #expect(routed)
        #expect(capture.tabIndex == 1)
        #expect(coordinator.pendingRequest?.spotID == "spot-1")
        #expect(coordinator.pendingRequest?.spot == spot)
        #expect(coordinator.pendingRequest?.source == .homeSpotCard)
    }

    @Test("Matching request consumption is exactly once")
    func matchingConsumptionIsExactlyOnce() {
        let coordinator = MapFocusCoordinator(notificationCenter: NotificationCenter())
        let spot = SpotTestHelpers.makeSpot(id: "spot-2", latitude: 1, longitude: 2)
        #expect(coordinator.requestFocus(on: spot, source: .homeSpotCard))
        let requestID = coordinator.pendingRequest?.id

        let consumed = coordinator.consumePending(id: requestID)

        #expect(consumed?.spotID == "spot-2")
        #expect(coordinator.consumePending(id: requestID) == nil)
    }

    @Test("Stale consumer cannot remove a newer request")
    func staleConsumerPreservesNewerRequest() {
        let coordinator = MapFocusCoordinator(notificationCenter: NotificationCenter())
        let first = SpotTestHelpers.makeSpot(id: "first", latitude: 1, longitude: 2)
        let second = SpotTestHelpers.makeSpot(id: "second", latitude: 3, longitude: 4)
        #expect(coordinator.requestFocus(on: first, source: .homeSpotCard))
        let staleID = coordinator.pendingRequest?.id
        #expect(coordinator.requestFocus(on: second, source: .homeSpotCard))

        #expect(coordinator.consumePending(id: staleID) == nil)
        #expect(coordinator.pendingRequest?.spotID == "second")
    }

    @Test("Invalid snapshot does not replace a pending request")
    func invalidSnapshotDoesNotReplacePendingRequest() {
        let coordinator = MapFocusCoordinator(notificationCenter: NotificationCenter())
        let valid = SpotTestHelpers.makeSpot(id: "valid", latitude: 1, longitude: 2)
        #expect(coordinator.requestFocus(on: valid, source: .homeSpotCard))
        let pendingID = coordinator.pendingRequest?.id

        let invalid = SpotTestHelpers.makeSpot(id: nil, latitude: 3, longitude: 4)
        #expect(coordinator.requestFocus(on: invalid, source: .homeSpotCard) == false)
        #expect(coordinator.pendingRequest?.id == pendingID)
    }

    @Test("Home Open in Map stores a one-shot Home return target")
    func homeOpenInMapStoresReturnTarget() {
        let coordinator = MapFocusCoordinator(notificationCenter: NotificationCenter())
        let spot = SpotTestHelpers.makeSpot(id: "return-1", latitude: 10, longitude: 20)
        #expect(coordinator.requestFocus(on: spot, source: .homeSpotCard))
        #expect(coordinator.pendingHomeReturnSpotID == "return-1")
        #expect(coordinator.peekHomeReturn()?.spotID == "return-1")

        let first = coordinator.consumeHomeReturn()
        #expect(first?.spotID == "return-1")
        #expect(coordinator.consumeHomeReturn() == nil)
        #expect(coordinator.pendingHomeReturnSpotID == nil)
    }

    @Test("Invalid Home Open in Map does not set a return target")
    func invalidHomeOpenDoesNotSetReturnTarget() {
        let coordinator = MapFocusCoordinator(notificationCenter: NotificationCenter())
        let invalid = SpotTestHelpers.makeSpot(id: "bad", latitude: 0, longitude: 0)
        #expect(coordinator.requestFocus(on: invalid, source: .homeSpotCard) == false)
        #expect(coordinator.pendingHomeReturnSpotID == nil)
    }
}

private final class NotificationCapture: @unchecked Sendable {
    var tabIndex: Int?
}
