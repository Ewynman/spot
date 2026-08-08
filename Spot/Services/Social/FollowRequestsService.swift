import Foundation
import Supabase

struct FollowRequest: Identifiable, Hashable {
    let id: String
    let requesterUid: String
    let username: String?
    let photoURL: String?
    let createdAt: Date?
}

final class FollowRequestsService {
    static let shared = FollowRequestsService()
    private init() {}

    struct Page {
        let items: [FollowRequest]
        /// Pass as `start` for the next `fetchPage` call, or nil when no more pages.
        let nextStart: Int?
    }

    private struct FollowRequestRow: Decodable {
        let id: UUID
        let requester_id: UUID
        let created_at: String
    }

    private struct UserMini: Decodable {
        let id: UUID
        let username: String
        let profile_image_url: String?
    }

    func countPending(targetUserId: String) async throws -> Int {
        guard let target = InputValidation.parseUUID(targetUserId, context: "FollowRequestsService.countPending") else { return 0 }
        struct IdRow: Decodable { let id: UUID }
        let rows: [IdRow] = try await supabase
            .from("follow_requests")
            .select("id", head: false)
            .eq("target_user_id", value: target)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows.count
    }

    func fetchPage(for targetUid: String, start: Int, pageSize: Int) async throws -> Page {
        guard let target = InputValidation.parseUUID(targetUid, context: "FollowRequestsService.fetchPage") else {
            return Page(items: [], nextStart: nil)
        }

        let rows: [FollowRequestRow] = try await supabase
            .from("follow_requests")
            .select("id,requester_id,created_at")
            .eq("target_user_id", value: target)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .range(from: start, to: start + pageSize - 1)
            .execute()
            .value

        let requesterIds = rows.map(\.requester_id)
        var usersById: [UUID: UserMini] = [:]
        if !requesterIds.isEmpty {
            let users: [UserMini] = try await supabase
                .from(SupabaseTableName.usersPublic)
                .select("id,username,profile_image_url")
                .in("id", values: requesterIds)
                .execute()
                .value
            for u in users { usersById[u.id] = u }
        }

        let items: [FollowRequest] = rows.map { row in
            let u = usersById[row.requester_id]
            return FollowRequest(
                id: row.id.uuidString,
                requesterUid: row.requester_id.uuidString,
                username: u?.username,
                photoURL: u?.profile_image_url,
                createdAt: SpotSupabaseRepository.parseTimestamptz(row.created_at)
            )
        }

        let nextStart = rows.count == pageSize ? (start + pageSize) : nil
        return Page(items: items, nextStart: nextStart)
    }

    func accept(requesterUid: String, targetUid: String) async throws {
        guard let requester = InputValidation.parseUUID(requesterUid, context: "FollowRequestsService.accept.requester"),
              let target = InputValidation.parseUUID(targetUid, context: "FollowRequestsService.accept.target")
        else {
            throw NSError(domain: "FollowRequestsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }

        SpotLogger.log(FollowRequestsServiceLogs.followRequestAccepted, details: ["requesterUid": requesterUid])

        struct FollowInsert: Encodable {
            let follower_id: UUID
            let followee_id: UUID
        }

        do {
            try await supabase
                .from("follows")
                .insert(FollowInsert(follower_id: requester, followee_id: target))
                .execute()
        } catch {
            // Idempotent: edge may already exist.
        }

        try await supabase
            .from("follow_requests")
            .delete()
            .eq("requester_id", value: requester)
            .eq("target_user_id", value: target)
            .eq("status", value: "pending")
            .execute()

        await AuthorPrivacyCache.shared.invalidate(authorId: requesterUid)
        
        // Notify the requester that their follow request was accepted
        // Note: This is a client-side local notification. In production, this
        // should be handled by a backend push notification service triggered
        // by the database follow event.
        Task { @MainActor in
            await notifyFollowRequestAcceptedByCurrentUser(acceptedUserId: requesterUid)
        }
    }

    func deny(requesterUid: String, targetUid: String) async throws {
        guard let requester = InputValidation.parseUUID(requesterUid, context: "FollowRequestsService.deny.requester"),
              let target = InputValidation.parseUUID(targetUid, context: "FollowRequestsService.deny.target")
        else {
            throw NSError(domain: "FollowRequestsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }

        SpotLogger.log(FollowRequestsServiceLogs.followRequestDenied, details: ["requesterUid": requesterUid])

        try await supabase
            .from("follow_requests")
            .delete()
            .eq("requester_id", value: requester)
            .eq("target_user_id", value: target)
            .eq("status", value: "pending")
            .execute()
    }
    
    // MARK: - Notification Helpers
    
    /// Sends a notification to the requester that their follow request was accepted.
    /// This is a local client-side notification for demonstration. In production,
    /// this should be replaced with a backend push notification triggered by
    /// database events (e.g., Supabase Edge Function or database trigger).
    private func notifyFollowRequestAcceptedByCurrentUser(acceptedUserId: String) async {
        // Fetch the username of the current user (the acceptor)
        guard let currentUserId = try? await supabase.auth.session.user.id else { return }
        
        struct UserRow: Decodable {
            let username: String
        }
        
        guard let userRow: UserRow = try? await supabase
            .from("users")
            .select("username")
            .eq("id", value: currentUserId)
            .single()
            .execute()
            .value
        else { return }
        
        await NotificationService.shared.notifyFollowRequestAccepted(
            by: userRow.username,
            acceptorUid: currentUserId.uuidString
        )
    }
}
