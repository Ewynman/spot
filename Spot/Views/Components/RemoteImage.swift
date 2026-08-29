//
//  RemoteImage.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import UIKit
import ImageIO

struct RemoteImageFailure: Error {
    let url: URL
    let statusCode: Int?
    let underlying: Error
    let mimeType: String?
    let bodyPreview: String?

    var nsError: NSError { underlying as NSError }
}

enum RemoteImagePhase {
    case empty
    case success(Image)
    case failure(RemoteImageFailure)
}

/// Async image loader that exposes HTTP status on failures (useful for debugging signed Supabase Storage URLs).
struct RemoteImage<Content: View>: View {
    private let url: URL
    private let scale: CGFloat
    private let transaction: Transaction
    private let maxPixelSize: CGFloat
    private let content: (RemoteImagePhase) -> Content

    @State private var phase: RemoteImagePhase = .empty

    init(
        url: URL,
        scale: CGFloat = 1.0,
        maxPixelSize: CGFloat = 1024,
        transaction: Transaction = Transaction(animation: .default),
        @ViewBuilder content: @escaping (RemoteImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.maxPixelSize = maxPixelSize
        self.transaction = transaction
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    private func setPhase(_ newPhase: RemoteImagePhase) {
        withTransaction(transaction) {
            phase = newPhase
        }
    }

    private func load() async {
        await MainActor.run { setPhase(.empty) }
        if let cached = RemoteImagePipeline.shared.cachedImage(for: url) {
            await MainActor.run { setPhase(.success(Image(uiImage: cached))) }
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return }
            let http = response as? HTTPURLResponse
            let status = http?.statusCode

            if let status, !(200...299).contains(status) {
                throw makeFailure(
                    statusCode: status,
                    underlying: NSError(domain: "RemoteImage", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP status \(status)"]),
                    mimeType: http?.mimeType,
                    data: data
                )
            }

            guard let ui = downsampledImage(from: data, maxPixelSize: maxPixelSize, scale: scale) else {
                throw makeFailure(
                    statusCode: status,
                    underlying: NSError(domain: "RemoteImage", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]),
                    mimeType: http?.mimeType,
                    data: data
                )
            }

            if Task.isCancelled { return }
            RemoteImagePipeline.shared.cache(image: ui, for: url)
            await MainActor.run { setPhase(.success(Image(uiImage: ui))) }
        } catch {
            if Task.isCancelled { return }
            // Best-effort to recover status code if error is our typed failure
            if let typed = error as? RemoteImageFailure {
                await MainActor.run { setPhase(.failure(typed)) }
                return
            }
            await MainActor.run {
                setPhase(.failure(RemoteImageFailure(
                    url: url,
                    statusCode: nil,
                    underlying: error,
                    mimeType: nil,
                    bodyPreview: nil
                )))
            }
        }
    }

    private func makeFailure(statusCode: Int?, underlying: Error, mimeType: String?, data: Data) -> RemoteImageFailure {
        var preview: String? = nil
        if !data.isEmpty {
            // Firebase error bodies are usually JSON; keep a short prefix to avoid huge logs.
            preview = String(data: data.prefix(512), encoding: .utf8)
        }
        return RemoteImageFailure(
            url: url,
            statusCode: statusCode,
            underlying: underlying,
            mimeType: mimeType,
            bodyPreview: preview
        )
    }

    private func downsampledImage(from data: Data, maxPixelSize: CGFloat, scale: CGFloat) -> UIImage? {
        let sourceOptions: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let pixelSize = max(maxPixelSize * scale, 1)
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

enum RemoteImageMemory {
    static func clearCache() {
        RemoteImagePipeline.shared.clearMemoryCache()
    }
}

private final class RemoteImagePipeline {
    static let shared = RemoteImagePipeline()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 180
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func cache(image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: max(cost, 1))
    }

    func clearMemoryCache() {
        cache.removeAllObjects()
    }
}

