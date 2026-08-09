//
//  Spot.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//

import Foundation
import CoreLocation

struct Spot: Identifiable, Codable, Equatable, Hashable {
    var id: String?
    var userId: String?
    var username: String?
    var userProfileImageURL: String?
    var imageURL: String?
    var thumbnailURL: String?
    var imageURLs: [String]?
    /// Ordered `spot_images.id` values when known (edit / enrichment).
    var imageIds: [String]?
    var vibeTag: String?
    var vibeTags: [String]?
    /// Server `spots.vibe_display_mode`. Defaults to rotating when absent.
    var vibeDisplayMode: VibeDisplayMode?
    /// Vibe labels ordered by `spot_images.sort_index` when `vibeDisplayMode == .photoSynced`.
    var photoSyncedVibeLabels: [String]?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var likes: Int?
    var isLiked: Bool?
    var isSaved: Bool?
    var createdAt: Date?
    // Optional denormalized snapshot to enable quick pre-filtering.
    var authorIsPrivate: Bool?
    /// Server-persisted width/height display ratio for the Spot media shell (cover photo). Optional for legacy rows.
    var mediaDisplayAspectRatio: Double?
    /// Optional media row count from `spots.media_count` when selected with the spot row.
    var mediaCount: Int?
    /// When known (e.g. feed enrichment), gates multi-vibe card UI for non‑Pro authors.
    var authorIsPro: Bool?

    // Explicit initializer to preserve source compatibility for existing call sites
    init(
        id: String? = nil,
        userId: String? = nil,
        username: String? = nil,
        userProfileImageURL: String? = nil,
        imageURL: String? = nil,
        thumbnailURL: String? = nil,
        vibeTag: String? = nil,
        vibeTags: [String]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        likes: Int? = nil,
        isLiked: Bool? = nil,
        isSaved: Bool? = nil,
        createdAt: Date? = nil,
        authorIsPrivate: Bool? = nil,
        imageURLs: [String]? = nil,
        imageIds: [String]? = nil,
        mediaDisplayAspectRatio: Double? = nil,
        mediaCount: Int? = nil,
        authorIsPro: Bool? = nil,
        vibeDisplayMode: VibeDisplayMode? = nil,
        photoSyncedVibeLabels: [String]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userProfileImageURL = userProfileImageURL
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.imageURLs = imageURLs
        self.imageIds = imageIds
        self.vibeTag = vibeTag
        self.vibeTags = vibeTags ?? (vibeTag.map { [$0] } ?? [])
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.likes = likes
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.createdAt = createdAt
        self.authorIsPrivate = authorIsPrivate
        self.mediaDisplayAspectRatio = mediaDisplayAspectRatio
        self.mediaCount = mediaCount
        self.authorIsPro = authorIsPro
        self.vibeDisplayMode = vibeDisplayMode
        self.photoSyncedVibeLabels = photoSyncedVibeLabels
    }

    static func withResolvedLocation(_ spot: Spot) async -> Spot {
        var spot = spot
        let hasCustomLocation = !(spot.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if !hasCustomLocation, let latitude = spot.latitude, let longitude = spot.longitude {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    if let name = placemark.name, !name.isEmpty {
                        spot.locationName = name
                    } else if let city = placemark.locality, let state = placemark.administrativeArea {
                        spot.locationName = "\(city), \(state)"
                    }
                }
            } catch {
                SpotLogger.log(SpotModelLogs.geocodingFailed, details: ["error": error.localizedDescription])
            }
        }
        return spot
    }

    static func == (lhs: Spot, rhs: Spot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var displayVibeTags: [String] {
        if let vibeTags, !vibeTags.isEmpty {
            return vibeTags
        }
        if let vibeTag, !vibeTag.isEmpty {
            return [vibeTag]
        }
        return []
    }

    /// Card / rotating tag UI: multiple vibes only when the author is Pro; otherwise first tag only.
    func visibleVibeLabelsForCard() -> [String] {
        let all = displayVibeTags
        guard all.count > 1 else { return all }
        if authorIsPro == true { return all }
        return [all[0]]
    }

    var resolvedVibeDisplayMode: VibeDisplayMode {
        vibeDisplayMode ?? .rotating
    }

    /// Labels for the vibe sheet: photo order when synced, otherwise creator vibe order.
    func vibeLabelsForSheet() -> [String] {
        if resolvedVibeDisplayMode == .photoSynced,
           let synced = photoSyncedVibeLabels,
           !synced.isEmpty {
            return synced
        }
        return visibleVibeLabelsForCard()
    }

    func cardVibeLabel(forCommittedPhotoIndex index: Int) -> String? {
        let visible = visibleVibeLabelsForCard()
        guard !visible.isEmpty else { return nil }
        if resolvedVibeDisplayMode == .photoSynced {
            return VibePhotoMappingPolicy.syncedLabel(
                photoSyncedVibeLabels: photoSyncedVibeLabels,
                index: index,
                fallback: visible
            )
        }
        return visible.first
    }
}
