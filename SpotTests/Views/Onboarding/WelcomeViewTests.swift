//
//  WelcomeViewTests.swift
//  SpotTests
//

import Testing
import CoreGraphics
@testable import Spot

struct WelcomeViewTests {

    @Test func defaultMotionEnablesAmbientHeroAnimation() {
        let configuration = WelcomeHeroMotionConfiguration.resolved(reduceMotionEnabled: false)

        #expect(configuration.oneTimeEntranceEnabled)
        #expect(configuration.continuousAnimationsEnabled)
        #expect(configuration.pinPulseEnabled)
    }

    @Test func reduceMotionDisablesContinuousHeroAnimation() {
        let configuration = WelcomeHeroMotionConfiguration.resolved(reduceMotionEnabled: true)

        #expect(configuration.oneTimeEntranceEnabled)
        #expect(configuration.continuousAnimationsEnabled == false)
        #expect(configuration.pinPulseEnabled == false)
    }

    @Test func welcomeLogLevelsMatchEventSeverity() {
        #expect(WelcomeViewLogs.screenViewed.level == .info)
        #expect(WelcomeViewLogs.appleSignInTapped.level == .info)
        #expect(WelcomeViewLogs.appleSignInFailed.level == .error)
    }

    @Test func heroUsesPersistentOrbitingItems() {
        let items = WelcomeHeroContent.orbitingItems

        #expect(items.count == 8)
        #expect(Set(items.map(\.id)).count == items.count)
        #expect(items.contains { item in
            if case .card = item.kind { return true }
            return false
        })
        #expect(items.filter { item in
            if case .tag = item.kind { return true }
            return false
        }.count == 3)
    }

    @Test func orbitPositionMovesAroundCenter() {
        let center = CGPoint(x: 100, y: 80)
        let right = WelcomeHeroSpin.position(center: center, radiusX: 30, radiusY: 20, angle: 0)
        let bottom = WelcomeHeroSpin.position(center: center, radiusX: 30, radiusY: 20, angle: .pi / 2)

        #expect(right.x == 130)
        #expect(right.y == 80)
        #expect(abs(bottom.x - 100) < 0.001)
        #expect(abs(bottom.y - 100) < 0.001)
    }

    @Test func spinMetricsKeepItemsFrontVisible() {
        let item = OrbitingItem(
            id: "test",
            kind: .pin(isHighlighted: false),
            orbitRadiusXMultiplier: 1,
            orbitRadiusYMultiplier: 1,
            phaseOffset: .pi / 2,
            size: CGSize(width: 20, height: 20)
        )

        let metrics = WelcomeHeroSpin.metrics(
            for: item,
            center: CGPoint(x: 100, y: 100),
            baseRadiusX: 30,
            baseRadiusY: 20,
            elapsedTime: 0,
            ringSpinSpeed: 1
        )

        #expect(abs(metrics.position.x - 100) < 0.001)
        #expect(abs(metrics.position.y - 120) < 0.001)
        #expect(abs(metrics.scale - 1) < 0.001)
        #expect(abs(metrics.opacity - 1) < 0.001)
        #expect(abs(metrics.zIndex - 10) < 0.001)
    }

    @Test func spinMetricsUseSharedRingSpeed() {
        let item = OrbitingItem(
            id: "test",
            kind: .pin(isHighlighted: false),
            orbitRadiusXMultiplier: 1,
            orbitRadiusYMultiplier: 1,
            phaseOffset: 0,
            size: CGSize(width: 20, height: 20)
        )

        let metrics = WelcomeHeroSpin.metrics(
            for: item,
            center: CGPoint(x: 100, y: 100),
            baseRadiusX: 30,
            baseRadiusY: 20,
            elapsedTime: 8,
            ringSpinSpeed: (2 * .pi) / 32
        )

        #expect(abs(metrics.theta - (.pi / 2)) < 0.001)
    }
}
