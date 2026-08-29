//
//  MapMarkerImageCacheTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import UIKit
import Testing
@testable import Spot

@MainActor
struct MapMarkerImageCacheTests {

    // MARK: - Fixtures

    /// Encodes a tiny solid-color PNG so the downsample path has real
    /// bytes to work with. 8×8 keeps the fixture cheap; the cache
    /// downsamples again during `setObject`.
    private static func pngData(color: UIColor, size: CGSize = CGSize(width: 8, height: 8)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    private static func makeCache() -> MapMarkerImageCache {
        MapMarkerImageCache(countLimit: 4, costLimit: 4 * 1024 * 1024)
    }

    // MARK: - Downsampling

    @Test func downsamplesToRequestedPixelSize() {
        let data = Self.pngData(color: .red, size: CGSize(width: 64, height: 64))
        let image = MapMarkerImageCache.downsample(data: data, toPixelSize: 32)
        #expect(image != nil)
        // ImageIO uses `kCGImageSourceThumbnailMaxPixelSize`, so both edges
        // land at ≤ 32 pixels for a square source.
        #expect(Int(image?.cgImage?.width ?? 0) <= 32)
        #expect(Int(image?.cgImage?.height ?? 0) <= 32)
    }

    @Test func downsampleReturnsNilForInvalidData() {
        let image = MapMarkerImageCache.downsample(
            data: Data("not-an-image".utf8),
            toPixelSize: 32
        )
        #expect(image == nil)
    }

    @Test func downsampleReturnsNilForZeroPixelSize() {
        let data = Self.pngData(color: .green)
        let image = MapMarkerImageCache.downsample(data: data, toPixelSize: 0)
        #expect(image == nil)
    }

    // MARK: - Fetch path

    @Test func cacheHitReturnsWithoutNetwork() async {
        let cache = Self.makeCache()
        let url = URL(string: "https://example.com/a.jpg")!
        let data = Self.pngData(color: .blue)

        var callCount = 0
        cache.dataProvider = { _, cb in
            callCount += 1
            cb(data, nil, nil)
        }

        _ = await withCheckedContinuation { (cont: CheckedContinuation<MapMarkerImageCache.LoadResult, Never>) in
            cache.fetch(url, targetPixelSize: 32) { cont.resume(returning: $0) }
        }

        let second = await withCheckedContinuation { (cont: CheckedContinuation<MapMarkerImageCache.LoadResult, Never>) in
            cache.fetch(url, targetPixelSize: 32) { cont.resume(returning: $0) }
        }

        #expect(callCount == 1)
        #expect(second.source == .cache)
        #expect(second.image != nil)
    }

    @Test func networkErrorDeliversNilAndCachesNothing() async {
        let cache = Self.makeCache()
        let url = URL(string: "https://example.com/bad.jpg")!
        cache.dataProvider = { _, cb in
            cb(nil, nil, URLError(.notConnectedToInternet))
        }

        let result = await withCheckedContinuation { (cont: CheckedContinuation<MapMarkerImageCache.LoadResult, Never>) in
            cache.fetch(url, targetPixelSize: 32) { cont.resume(returning: $0) }
        }

        #expect(result.image == nil)
        #expect(result.source == .network)
        // Failed load must not seed the cache; a retry should re-fetch.
        #expect(cache.cachedImage(for: url) == nil)
    }

    @Test func concurrentFetchesForSameURLShareOneNetworkRequest() async {
        let cache = Self.makeCache()
        let url = URL(string: "https://example.com/shared.jpg")!
        let data = Self.pngData(color: .orange)

        var networkCallCount = 0
        var pendingCallbacks: [(Data?, URLResponse?, Error?) -> Void] = []
        cache.dataProvider = { _, cb in
            networkCallCount += 1
            // Simulate an in-flight request by buffering the callback so
            // both callers land in the in-flight table before completion.
            pendingCallbacks.append(cb)
        }

        async let a: MapMarkerImageCache.LoadResult = withCheckedContinuation { cont in
            cache.fetch(url, targetPixelSize: 32) { cont.resume(returning: $0) }
        }
        async let b: MapMarkerImageCache.LoadResult = withCheckedContinuation { cont in
            cache.fetch(url, targetPixelSize: 32) { cont.resume(returning: $0) }
        }

        // Yield so both fetches register in `inFlight`.
        try? await Task.sleep(nanoseconds: 20_000_000)
        pendingCallbacks.forEach { $0(data, nil, nil) }

        let (resultA, resultB) = await (a, b)
        #expect(networkCallCount == 1)
        #expect(resultA.image != nil)
        #expect(resultB.image != nil)
    }

    @Test func cancelBeforeCompletionSuppressesCallback() async {
        let cache = Self.makeCache()
        let url = URL(string: "https://example.com/canceled.jpg")!
        let data = Self.pngData(color: .yellow)

        var deferred: ((Data?, URLResponse?, Error?) -> Void)?
        cache.dataProvider = { _, cb in
            deferred = cb
        }

        var receivedResult = false
        let handle = cache.fetch(url, targetPixelSize: 32) { _ in
            receivedResult = true
        }
        // Small delay to let fetch register.
        try? await Task.sleep(nanoseconds: 10_000_000)
        cache.cancel(handle)
        deferred?(data, nil, nil)

        // Allow any main-queue delivery attempts to drain.
        try? await Task.sleep(nanoseconds: 40_000_000)
        #expect(receivedResult == false)
        // The response still seeds the cache so a later fetch is instant.
        #expect(cache.cachedImage(for: url) != nil)
    }
}
