//
//  MapMarkerImageCache.swift
//  Spot
//
//  Bounded, downsampling in-memory cache for photo pin marker thumbnails.
//
//  The map can render up to ~250 spots per viewport; each photo pin needs a
//  tiny circular thumbnail (~44 pt / 132 px @3x). Loading original signed
//  media into `UIImage` would blow the map's memory budget, so we:
//
//   * Downsample decoded bytes to a marker-sized `UIImage` via
//     `CGImageSourceCreateThumbnailAtIndex` (never fully decode the source).
//   * Cache the small `UIImage` in `NSCache` with count + byte-cost limits.
//   * Deduplicate concurrent fetches for the same URL so pan/zoom bursts do
//     not fan out into hundreds of redundant network requests.
//   * Allow callers to cancel their interest in a request (via `Handle`)
//     without cancelling shared work; the underlying request completes and
//     seeds the cache for future callers.
//
//  The cache is intentionally separate from `RemoteImagePipeline` (feed
//  cards) and `MapAvatarImageCache` (user-location avatar). Marker
//  thumbnails have very different sizing/lifetime characteristics and
//  should not evict full-size feed thumbnails, or vice-versa.
//

import UIKit
import ImageIO

/// Source of a completed `MapMarkerImageCache.fetch` result. Used by
/// callers to emit diagnostic analytics (`map_marker_image_load`).
enum MapMarkerImageLoadSource: String {
    case cache
    case network
}

/// Bounded in-memory cache for map marker photo previews.
final class MapMarkerImageCache {

    static let shared = MapMarkerImageCache()

    /// Opaque handle representing one caller's interest in an in-flight
    /// fetch. Pass back to `cancel(_:)` to stop receiving the callback.
    struct Handle {
        let token: UUID
        fileprivate let url: URL
    }

    /// Result payload delivered on the main queue.
    struct LoadResult {
        let image: UIImage?
        let source: MapMarkerImageLoadSource
        let elapsed: TimeInterval
    }

    private let cache = NSCache<NSURL, UIImage>()
    private let workQueue: DispatchQueue
    private let lock = NSLock()
    /// URL → (token → completion). All access under `lock`.
    private var inFlight: [URL: [UUID: (LoadResult) -> Void]] = [:]

    /// Test hook: overrides `URLSession.shared.dataTask(with:)` when set.
    /// Signature mirrors `URLSession.dataTask(with:completionHandler:)`.
    /// Left as `nil` in production so `URLSession.shared` is used directly.
    var dataProvider: ((URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void)?

    init(
        countLimit: Int = Constants.MapDesign.photoPinImageCacheCount,
        costLimit: Int = Constants.MapDesign.photoPinImageCacheCostBytes
    ) {
        cache.countLimit = max(1, countLimit)
        cache.totalCostLimit = max(0, costLimit)
        workQueue = DispatchQueue(
            label: "com.spot.map.marker-cache",
            qos: .userInitiated,
            attributes: .concurrent
        )
    }

    // MARK: - Public API

    /// Return a cached image without touching the network.
    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Fetch a downsampled thumbnail for `url`. The completion is invoked
    /// on the main queue exactly once, unless the returned `Handle` is
    /// cancelled first.
    ///
    /// - Parameters:
    ///   - url: The signed image URL to load.
    ///   - targetPixelSize: The pixel size of the destination image. This
    ///     is the pixel — not point — size, and should already incorporate
    ///     screen scale (e.g. `44 * 3 = 132`).
    ///   - completion: Called on the main queue with the load result.
    /// - Returns: A cancellable handle for this specific caller.
    @discardableResult
    func fetch(
        _ url: URL,
        targetPixelSize: CGFloat,
        completion: @escaping (LoadResult) -> Void
    ) -> Handle {
        let token = UUID()
        let start = CFAbsoluteTimeGetCurrent()

        if let cached = cache.object(forKey: url as NSURL) {
            DispatchQueue.main.async {
                completion(LoadResult(
                    image: cached,
                    source: .cache,
                    elapsed: CFAbsoluteTimeGetCurrent() - start
                ))
            }
            return Handle(token: token, url: url)
        }

        lock.lock()
        if inFlight[url] != nil {
            inFlight[url]?[token] = completion
            lock.unlock()
            return Handle(token: token, url: url)
        }
        inFlight[url] = [token: completion]
        lock.unlock()

        let pixelSize = max(1, Int(targetPixelSize.rounded()))
        let dataFetch = dataProvider ?? { url, cb in
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            URLSession.shared.dataTask(with: request) { data, response, error in
                cb(data, response, error)
            }.resume()
        }

        dataFetch(url) { [weak self] data, _, error in
            guard let self else { return }
            self.workQueue.async {
                let image: UIImage?
                if error == nil,
                   let data,
                   let downsampled = Self.downsample(data: data, toPixelSize: pixelSize) {
                    image = downsampled
                    let cost = pixelSize * pixelSize * 4
                    self.cache.setObject(downsampled, forKey: url as NSURL, cost: cost)
                } else {
                    image = nil
                }
                self.deliver(
                    LoadResult(
                        image: image,
                        source: .network,
                        elapsed: CFAbsoluteTimeGetCurrent() - start
                    ),
                    for: url
                )
            }
        }

        return Handle(token: token, url: url)
    }

    /// Withdraw a caller's interest in a fetch. If other callers are still
    /// awaiting the same URL, the shared network request continues and
    /// seeds the cache. If this was the last interested caller, the URL is
    /// removed from the in-flight table so a fresh fetch can start later.
    func cancel(_ handle: Handle) {
        lock.lock()
        defer { lock.unlock() }
        guard var pending = inFlight[handle.url] else { return }
        pending.removeValue(forKey: handle.token)
        if pending.isEmpty {
            inFlight.removeValue(forKey: handle.url)
        } else {
            inFlight[handle.url] = pending
        }
    }

    /// Drop all cached images. Called on sign-out and low-memory warnings.
    func clear() {
        cache.removeAllObjects()
    }

    // MARK: - Internal helpers

    private func deliver(_ result: LoadResult, for url: URL) {
        lock.lock()
        let callbacks = inFlight.removeValue(forKey: url) ?? [:]
        lock.unlock()
        guard !callbacks.isEmpty else { return }
        DispatchQueue.main.async {
            for callback in callbacks.values {
                callback(result)
            }
        }
    }

    /// Downsample `data` to a `UIImage` whose largest edge is `pixelSize`.
    /// Uses ImageIO so the source bitmap is never fully decoded.
    static func downsample(data: Data, toPixelSize pixelSize: Int) -> UIImage? {
        guard pixelSize > 0 else { return nil }
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
