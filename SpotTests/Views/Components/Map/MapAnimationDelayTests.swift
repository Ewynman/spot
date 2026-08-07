//
//  MapAnimationDelayTests.swift
//  SpotTests
//
//  The pin entry animation needs a *stable*, *bounded* per-pin delay so
//  re-renders don't restart the dance and the staggered batch always
//  finishes within `pinStaggerCap` seconds. We use FNV-1a + bucketing —
//  Swift's stdlib `Hasher` randomizes per-process and is unsafe here.
//

import CoreLocation
import Testing
@testable import Spot

struct MapAnimationDelayTests {

    private let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    @Test func delayIsDeterministicForSameId() {
        let d1 = MapAnimationDelay.delay(forSpotId: "abc", fallback: coord)
        let d2 = MapAnimationDelay.delay(forSpotId: "abc", fallback: coord)
        #expect(d1 == d2)
    }

    @Test func delayIsBoundedByStaggerCap() {
        let inputs = ["a", "b", "c", "d", "abcdefghijklmnopqrstuvwxyz"]
        for id in inputs {
            let d = MapAnimationDelay.delay(forSpotId: id, fallback: coord)
            #expect(d >= 0)
            #expect(d <= Constants.MapDesign.pinStaggerCap)
        }
    }

    @Test func delayIsNonZeroForBucketingInputs() {
        // Generate enough varied inputs that at least a few should hash into
        // non-zero buckets — guards against accidental "always returns 0"
        // regressions.
        var nonZero = 0
        for i in 0..<200 {
            let d = MapAnimationDelay.delay(forSpotId: "spot-\(i)", fallback: coord)
            if d > 0 { nonZero += 1 }
        }
        #expect(nonZero > 50)
    }

    @Test func nilOrEmptyIdFallsBackToCoordinate() {
        let c1 = CLLocationCoordinate2D(latitude: 1, longitude: 2)
        let c2 = CLLocationCoordinate2D(latitude: 9, longitude: 8)
        let dNilA = MapAnimationDelay.delay(forSpotId: nil, fallback: c1)
        let dEmptyA = MapAnimationDelay.delay(forSpotId: "", fallback: c1)
        let dNilB = MapAnimationDelay.delay(forSpotId: nil, fallback: c2)
        // Same coordinate → same delay; different coordinate → can be different.
        #expect(dNilA == dEmptyA)
        // We don't assert dNilA != dNilB (they could collide), but every
        // value must still be bounded.
        #expect(dNilB <= Constants.MapDesign.pinStaggerCap)
    }

    @Test func delaysSnapToStaggerStepGrid() {
        // Every produced delay should be on the `pinStaggerStep` grid
        // because we map the hash to an integer bucket.
        let step = Constants.MapDesign.pinStaggerStep
        for i in 0..<60 {
            let d = MapAnimationDelay.delay(forSpotId: "grid-\(i)", fallback: coord)
            let buckets = (d / step).rounded()
            let snapped = buckets * step
            // Allow a tiny floating-point slop.
            #expect(abs(d - snapped) < 1e-9)
        }
    }
}
