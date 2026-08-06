//
//  SpotPublishCoordinator.swift
//  Spot
//
//  Background spot publish: Supabase Storage + Postgres (`spots` / `spot_images` / `vibe_tags`).
//

import Foundation
import SwiftUI
import UIKit

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
    let sourceDraftID: String?
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
            let signedFirstImage = try? await SpotSupabaseRepository.signFirstImageURLForSpot(spotId: spotId)

            let postedSpot = Spot(
                id: spotIdString,
                userId: draft.userId,
                username: nil,
                userProfileImageURL: nil,
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
                mediaCount: draft.imageJPEGs.count
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
        case .uploading: return "Posting your spot…"
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
        return try await withThrowingTaskGroup(of: UUID.self) { group in
            group.addTask {
                try await SpotSupabaseRepository.publishSpotFromDraft(
                    userId: userId,
                    imageJPEGs: draft.imageJPEGs,
                    vibeTags: draft.vibeTags,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    locationName: draft.placeName
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
}
