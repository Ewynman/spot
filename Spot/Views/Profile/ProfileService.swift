//
//  ProfileService.swift
//  Spot
//
//  Created by Edward Wynman on 8/6/25.
//

import Foundation
import Supabase

struct ProfileData {
    let username: String
    let profileImageURL: String?
    let isPrivate: Bool
    let isPro: Bool
    let isFollowing: Bool
    let hasRequested: Bool
    let canView: Bool
    let spots: [Spot]
}

private enum ProfileSupabaseSchema {
    struct PublicUserRow: Decodable {
        let id: UUID
        let username: String
        let profile_image_url: String?
        let is_private: Bool
        let is_pro: Bool
        let pro_until: String?
    }

    struct IdRow: Decodable {
        let id: UUID
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseProUntil(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = iso8601Fractional.date(from: raw) { return d }
        if let d = iso8601Plain.date(from: raw) { return d }
        return nil
    }

    /// Explicit `pro_until` wins; otherwise use `is_pro` flag.
    static func effectiveIsPro(proUntilRaw: String?, isPro: Bool) -> Bool {
        if let until = parseProUntil(proUntilRaw) {
            return until > Date()
        }
        return isPro
    }

    static func hasFollowEdge(
        followerId: UUID,
        followeeId: UUID
    ) async throws -> Bool {
        let rows: [IdRow] = try await supabase
            .from("follows")
            .select("id")
            .eq("follower_id", value: followerId)
            .eq("followee_id", value: followeeId)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    static func hasPendingFollowRequest(
        requesterId: UUID,
        targetUserId: UUID
    ) async throws -> Bool {
        let rows: [IdRow] = try await supabase
            .from("follow_requests")
            .select("id")
            .eq("requester_id", value: requesterId)
            .eq("target_user_id", value: targetUserId)
            .eq("status", value: "pending")
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }
}

enum ProfileService {
    static func fetchProfile(for userId: String?) async throws -> ProfileData {
        let id: String

        if let providedId = userId {
            id = providedId
        } else {
            guard let currentId = SpotAuthBridge.currentUserId else {
                throw NSError(domain: "No current user ID", code: 0)
            }
            id = currentId
        }

        SpotLogger.log(ProfileServiceLogs.fetchingProfileData, details: ["userId": id])

        guard let targetUUID = UUID(uuidString: id) else {
            throw NSError(
                domain: "ProfileService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid user id (expected UUID)."]
            )
        }

        let row: ProfileSupabaseSchema.PublicUserRow
        do {
            row = try await supabase
                .from(SupabaseTableName.usersPublic)
                .select("id,username,profile_image_url,is_private,is_pro,pro_until")
                .eq("id", value: targetUUID)
                .single()
                .execute()
                .value
        } catch {
            throw NSError(
                domain: "User not found",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }

        let username = row.username.isEmpty ? "User" : row.username
        let profileImageURL = row.profile_image_url
        let targetIsPrivate = row.is_private
        let targetIsPro = ProfileSupabaseSchema.effectiveIsPro(proUntilRaw: row.pro_until, isPro: row.is_pro)

        let currentUserId = SpotAuthBridge.currentUserId
        var isFollowing = false
        var hasRequested = false
        var canView = true
        if let currentUserId, currentUserId != id, let viewerUUID = UUID(uuidString: currentUserId) {
            let followTask = Task {
                try await ProfileSupabaseSchema.hasFollowEdge(
                    followerId: viewerUUID,
                    followeeId: targetUUID
                )
            }
            let requestTask = Task {
                try await ProfileSupabaseSchema.hasPendingFollowRequest(
                    requesterId: viewerUUID,
                    targetUserId: targetUUID
                )
            }
            do {
                isFollowing = try await followTask.value
            } catch {
                SpotLogger.log(ProfileServiceLogs.followStateQueryFailed, details: [
                    "error": error.localizedDescription
                ])
                isFollowing = false
            }
            do {
                hasRequested = try await requestTask.value
            } catch {
                SpotLogger.log(ProfileServiceLogs.pendingFollowRequestQueryFailed, details: [
                    "error": error.localizedDescription
                ])
                hasRequested = false
            }
            canView = !targetIsPrivate || isFollowing
        }

        let spots: [Spot]
        if canView {
            spots = try await SpotSupabaseRepository.fetchSpotsForUser(
                userId: targetUUID,
                authorUsername: username,
                authorProfileImageURL: profileImageURL
            )
        } else {
            spots = []
        }

        return ProfileData(
            username: username,
            profileImageURL: profileImageURL,
            isPrivate: targetIsPrivate,
            isPro: targetIsPro,
            isFollowing: isFollowing,
            hasRequested: hasRequested,
            canView: currentUserId == id ? true : canView,
            spots: spots
        )
    }
}
