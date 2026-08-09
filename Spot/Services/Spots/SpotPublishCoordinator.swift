//
//  SpotPublishCoordinator.swift
//  Spot
//
//  Background spot publish: Supabase Storage + Postgres (`spots` / `spot_images` / `vibe_tags`).
//

import Foundation
import SwiftUI
import UIKit

enum SpotPublishProgress: Equatable, Sendable {
    case preparing
    case resolvingVibes
    case uploadingPhoto(index: Int, total: Int)
    case checkingPhoto(index: Int, total: Int)
    case publishing
    case finalizing
    case complete

    var fraction: Double {
        switch self {
        case .preparing: return 0.05
        case .resolvingVibes: return 0.12
        case let .uploadingPhoto(index, total):
            return photoFraction(index: index, total: total, stage: 0)
        case let .checkingPhoto(index, total):
            return photoFraction(index: index, total: total, stage: 0.65)
        case .publishing: return 0.9
        case .finalizing: return 0.97
        case .complete: return 1
        }
    }

    var title: String {
        switch self {
        case .preparing: return "Preparing your Spot…"
        case .resolvingVibes: return "Adding vibe tags…"
        case let .uploadingPhoto(index, total):
            return "Uploading photo \(min(index + 1, total)) of \(total)…"
        case let .checkingPhoto(index, total):
            return "Checking photo \(min(index + 1, total)) of \(total)…"
        case .publishing: return "Publishing your Spot…"
        case .finalizing: return "Finishing up…"
        case .complete: return "Spot posted"
        }
    }

    private func photoFraction(index: Int, total: Int, stage: Double) -> Double {
        let safeTotal = max(total, 1)
        let completed = min(max(Double(index) + stage, 0), Double(safeTotal))
        return 0.15 + 0.7 * completed / Double(safeTotal)
    }
}

/// Serializable draft so the publish pipeline does not retain `UIImage` after the composer resets.
struct SpotPublishDraft: Equatable {
    let imageJPEGs: [Data]
    /// Display aspect ratio (width/height) from the cover JPEG, clamped for feed stability.
    let coverMediaDisplayAspectRatio: CGFloat
    let vibeTags: [String]
    let latitude: Double
    let longitude: Double
    let placeName: String
    let userId: String
    let username: String?
    let userProfileImageURL: String?
    let sourceDraftID: String?
    let vibeDisplayMode: VibeDisplayMode

    init(
        imageJPEGs: [Data],
        coverMediaDisplayAspectRatio: CGFloat,
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        placeName: String,
        userId: String,
        username: String?,
        userProfileImageURL: String?,
        sourceDraftID: String?,
        vibeDisplayMode: VibeDisplayMode = .rotating
    ) {
        self.imageJPEGs = imageJPEGs
        self.coverMediaDisplayAspectRatio = coverMediaDisplayAspectRatio
        self.vibeTags = vibeTags
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.userId = userId
        self.username = username
        self.userProfileImageURL = userProfileImageURL
        self.sourceDraftID = sourceDraftID
        self.vibeDisplayMode = vibeDisplayMode
    }
}

@MainActor
protocol SpotPublishing: AnyObject {
    func enqueue(draft: SpotPublishDraft, onQueued: @escaping () -> Void)
}

@MainActor
final class SpotPublishCoordinator: ObservableObject, SpotPublishing {
    static let shared = SpotPublishCoordinator()
    /// Upload + Edge moderation + RPC publish can exceed the legacy short upload window.
    private let publishTimeoutSeconds: UInt64 = 90

    enum BannerPhase: Equatable {
        case hidden
        case uploading
    }

    @Published private(set) var bannerPhase: BannerPhase = .hidden
    @Published private(set) var publishProgress: SpotPublishProgress = .preparing
    @Published private(set) var showToast = false
    @Published private(set) var toastMessage = ""
    @Published private(set) var toastIsError = false

    private var pipelineTail: Task<Void, Never>?

    private init() {}

    func enqueue(draft: SpotPublishDraft, onQueued: @escaping () -> Void) {
        let previous = pipelineTail
        pipelineTail = Task { [weak self] in
            if let previous { await previous.value }
            guard let self else { return }
            await self.runPublish(draft: draft)
        }
        onQueued()
    }

    private func runPublish(draft: SpotPublishDraft) async {
        bannerPhase = .uploading
        publishProgress = .preparing

        guard UUID(uuidString: draft.userId) != nil else {
            await presentErrorToast("Error Posting Spot Try Again Later")
            NotificationCenter.default.post(name: .spotDidPostFailed, object: nil)
            bannerPhase = .hidden
            return
        }

        let jpegs = draft.imageJPEGs
        guard !jpegs.isEmpty else {
            await presentErrorToast("Error Posting Spot Try Again Later")
            NotificationCenter.default.post(name: .spotDidPostFailed, object: nil)
            bannerPhase = .hidden
            return
        }

        do {
            let spotId = try await publishSpotWithTimeout(draft: draft)
            let spotIdString = spotId.uuidString
            let postedAt = Date()
            publishProgress = .finalizing
            let signedFirstImage = try? await SpotSupabaseRepository.signFirstImageURLForSpot(spotId: spotId)

            let postedSpot = Self.makePostedSpot(
                draft: draft,
                spotId: spotIdString,
                signedFirstImage: signedFirstImage,
                postedAt: postedAt
            )

            SpotLogger.log(SpotPublishCoordinatorLogs.spotPublished, details: ["spotId": spotId.uuidString])
            AnalyticsService.shared.trackUserAction("spot_posted", contentType: "spot", contentId: spotId.uuidString, parameters: [
                "vibe_tag": draft.vibeTags.first ?? "",
                "has_multiple_images": jpegs.count > 1
            ])
            if let sourceDraftID = draft.sourceDraftID {
                PostDraftStore.deleteDraft(id: sourceDraftID)
            } else {
                PostDraftStore.clearAutosave()
            }
            NotificationCenter.default.post(
                name: .spotDidPostSuccess,
                object: nil,
                userInfo: ["postedSpot": postedSpot]
            )
            publishProgress = .complete
        } catch let error as PublishError {
            switch error {
            case .timedOut:
                SpotLogger.log(SpotPublishCoordinatorLogs.spotUploadTimedOut, details: [
                    "timeoutSeconds": publishTimeoutSeconds,
                    "userId": draft.userId
                ])
                await presentErrorToast("Upload timed out. Saved to drafts, try again later.")
                NotificationCenter.default.post(name: .spotDidPostFailed, object: nil)
            }
        } catch {
            let ns = error as NSError
            if ns.domain == "SpotImageModeration" {
                SpotLogger.log(SpotPublishCoordinatorLogs.spotUploadFailed, details: [
                    "error": error.localizedDescription,
                    "code": ns.code
                ])
                await presentErrorToast(ns.localizedDescription)
            } else {
                SpotLogger.log(SpotPublishCoordinatorLogs.spotUploadFailed, details: ["error": error.localizedDescription])
                await presentErrorToast("Error Posting Spot Try Again Later")
            }
            NotificationCenter.default.post(name: .spotDidPostFailed, object: nil)
        }

        bannerPhase = .hidden
    }

    var bannerTitle: String {
        switch bannerPhase {
        case .hidden: return ""
        case .uploading: return publishProgress.title
        }
    }

    private func presentErrorToast(_ message: String) async {
        toastMessage = message
        toastIsError = true
        withAnimation { showToast = true }
        let duration: UInt64 = 2_800_000_000
        try? await Task.sleep(nanoseconds: duration)
        withAnimation { showToast = false }
    }

    private enum PublishError: Error {
        case timedOut
    }

    private func publishSpotWithTimeout(draft: SpotPublishDraft) async throws -> UUID {
        let userId = try parseUserId(draft.userId)
        let progressHandler: @MainActor @Sendable (SpotPublishProgress) -> Void = { [weak self] progress in
            self?.publishProgress = progress
        }
        return try await withThrowingTaskGroup(of: UUID.self) { group in
            group.addTask {
                try await SpotSupabaseRepository.publishSpotFromDraft(
                    userId: userId,
                    imageJPEGs: draft.imageJPEGs,
                    vibeTags: draft.vibeTags,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    locationName: draft.placeName,
                    vibeDisplayMode: draft.vibeDisplayMode,
                    progress: progressHandler
                )
            }
            group.addTask { [publishTimeoutSeconds] in
                try await Task.sleep(nanoseconds: publishTimeoutSeconds * 1_000_000_000)
                throw PublishError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func parseUserId(_ raw: String) throws -> UUID {
        guard let uid = UUID(uuidString: raw) else {
            throw NSError(domain: "SpotPublishCoordinator", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }
        return uid
    }

    /// Builds the optimistic feed Spot after a successful publish (unit-tested).
    nonisolated static func makePostedSpot(
        draft: SpotPublishDraft,
        spotId: String,
        signedFirstImage: String?,
        postedAt: Date
    ) -> Spot {
        Spot(
            id: spotId,
            userId: draft.userId,
            username: draft.username,
            userProfileImageURL: draft.userProfileImageURL,
            imageURL: signedFirstImage,
            thumbnailURL: signedFirstImage,
            vibeTag: draft.vibeTags.first,
            vibeTags: draft.vibeTags,
            latitude: draft.latitude,
            longitude: draft.longitude,
            locationName: draft.placeName,
            likes: 0,
            isLiked: false,
            isSaved: false,
            createdAt: postedAt,
            authorIsPrivate: nil,
            imageURLs: signedFirstImage.map { [$0] } ?? nil,
            mediaDisplayAspectRatio: Double(draft.coverMediaDisplayAspectRatio),
            mediaCount: draft.imageJPEGs.count,
            authorIsPro: draft.vibeDisplayMode == .photoSynced
                || draft.vibeTags.count > 1
                || draft.imageJPEGs.count > 1,
            vibeDisplayMode: draft.vibeDisplayMode,
            photoSyncedVibeLabels: draft.vibeDisplayMode == .photoSynced ? draft.vibeTags : nil
        )
    }
}
