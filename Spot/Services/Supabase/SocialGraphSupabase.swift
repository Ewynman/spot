//
//  SocialGraphSupabase.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Supabase

enum SocialGraphSupabase {
    /// `follows.followee_id` values for the given follower.
    static func followingIds(followerId: UUID) async throws -> [String] {
        struct Row: Decodable { let followee_id: UUID }
        let rows: [Row] = try await supabase
            .from("follows")
            .select("followee_id")
            .eq("follower_id", value: followerId)
            .execute()
            .value
        return rows.map { $0.followee_id.uuidString }
    }

    /// Targets the user has a **pending** outgoing follow request to (`follow_requests.target_user_id`).
    static func outgoingPendingFollowTargetIds(requesterId: UUID) async throws -> [String] {
        struct Row: Decodable { let target_user_id: UUID }
        let rows: [Row] = try await supabase
            .from("follow_requests")
            .select("target_user_id")
            .eq("requester_id", value: requesterId)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows.map { $0.target_user_id.uuidString }
    }

    static func socialLists(for userId: UUID) async throws -> (following: [String], requestedTargets: [String]) {
        async let following = followingIds(followerId: userId)
        async let pending = outgoingPendingFollowTargetIds(requesterId: userId)
        return try await (following, pending)
    }
}
