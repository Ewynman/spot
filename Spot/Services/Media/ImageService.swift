//
//  ImageService.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import Foundation
import UIKit

class ImageService {
    static let shared = ImageService()
    private init() {
        // Cap image cache memory to avoid OOM on long sessions.
        imageCache.countLimit = 300
        imageCache.totalCostLimit = 64 * 1024 * 1024
    }

    private let imageCache = NSCache<NSString, UIImage>()
    private var failedURLs = Set<String>()
    private let maxRetries = 3
    private let maxFailedURLCount = 512

    /// Load image with retry logic and caching
    func loadImage(from urlString: String, spotId: String? = nil) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: urlString as NSString) {
            return cachedImage
        }

        // Check if URL has failed before
        if failedURLs.contains(urlString) {
            SpotLogger.log(ImageServiceLogs.skippingPreviouslyFailedUrl, details: ["url": urlString])
            return nil
        }

        // Ensure HTTPS URL
        guard let url = URL(string: urlString), url.scheme == "https" else {
            SpotLogger.log(ImageServiceLogs.invalidOrNonHttpsUrl, details: ["url": urlString])
            return nil
        }

        // Try loading with retries
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }

                // Cache successful image
                let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                imageCache.setObject(image, forKey: urlString as NSString, cost: max(cost, 1))

                SpotLogger.log(ImageServiceLogs.imageLoadedSuccessfully, details: ["host": url.host ?? "unknown", "spotId": spotId ?? "unknown"])
                return image

            } catch {
                let errorCode = (error as? URLError)?.code.rawValue ?? -1
                SpotLogger.log(ImageServiceLogs.imageLoadFailed, details: ["spotId": spotId ?? "unknown", "urlHost": url.host ?? "unknown", "code": errorCode, "attempt": attempt])

                if attempt == maxRetries {
                    // Final failure - mark URL as failed
                    failedURLs.insert(urlString)
                    if failedURLs.count > maxFailedURLCount {
                        failedURLs.removeAll(keepingCapacity: true)
                    }
                    SpotLogger.log(ImageServiceLogs.imageLoadFailedAnalytics, details: ["spotId": spotId ?? "nil", "urlHost": url.host ?? "unknown", "code": errorCode, "attempt": attempt])
                    Task { @MainActor in
                        AnalyticsService.shared.trackImageLoadFailure(spotId: spotId, urlHost: url.host, errorCode: errorCode, attempt: attempt)
                    }
                    return nil
                }

                // Exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }
        }

        return nil
    }

    /// Prefetch images for better UX
    func prefetchImages(for spots: [Spot], limit: Int = 9) {
        let urlsToPrefetch = spots.prefix(limit).compactMap { spot in
            spot.imageURL
        }

        Task {
            for url in urlsToPrefetch {
                _ = await loadImage(from: url, spotId: nil)
            }
        }
    }

    /// Clear cache (useful for memory management)
    func clearCache() {
        imageCache.removeAllObjects()
        failedURLs.removeAll(keepingCapacity: true)
    }

    /// Check if an image URL is valid and accessible
    func validateImageURL(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString), url.scheme == "https" else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    /// Convert gs:// URLs to https download URLs
    func convertGSUrlToHTTPS(_ gsUrl: String) -> String? {
        guard gsUrl.hasPrefix("gs://") else {
            return gsUrl
        }

        // For now, return nil to indicate conversion needed
        // Legacy gs:// URLs are not used by the Supabase signed-URL pipeline.
        SpotLogger.log(ImageServiceLogs.gsUrlConversionNeeded, details: ["gsUrl": gsUrl])
        return nil
    }
}
