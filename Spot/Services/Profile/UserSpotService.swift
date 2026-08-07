import Foundation
import Supabase

class UserSpotService {
    static let shared = UserSpotService()
    private var userId: String? { SpotAuthBridge.currentUserId }

    private struct UserListsRow: Decodable {
        let liked_spots: [UUID]?
        let bookmarked_spots: [UUID]?
    }

    private struct SpotRefInsert: Encodable {
        let user_id: UUID
        let spot_id: UUID
    }

    private struct SpotRefRow: Decodable {
        let spot_id: UUID
    }

    private struct BlockRow: Decodable {
        let blocked_user_id: UUID
    }

    private struct IdRow: Decodable {
        let id: UUID
    }

    private func withCurrentUserUUID(_ completion: @escaping (Result<UUID, Error>) -> Void) {
        guard let userId, let uid = UUID(uuidString: userId) else {
            completion(.failure(NSError(domain: "UserSpotService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user"])))
            return
        }
        completion(.success(uid))
    }

    private func fetchUserLists(for uid: UUID) async throws -> (liked: [String], bookmarked: [String]) {
        if let row: UserListsRow = try? await supabase
            .from("users")
            .select("liked_spots,bookmarked_spots")
            .eq("id", value: uid)
            .single()
            .execute()
            .value {
            let liked = (row.liked_spots ?? []).map(\.uuidString)
            let bookmarked = (row.bookmarked_spots ?? []).map(\.uuidString)
            return (liked, bookmarked)
        }

        let likesRows: [SpotRefRow] = (try? await supabase
            .from("spot_likes")
            .select("spot_id")
            .eq("user_id", value: uid)
            .execute()
            .value) ?? []
        let bookmarkRows: [SpotRefRow] = (try? await supabase
            .from("spot_bookmarks")
            .select("spot_id")
            .eq("user_id", value: uid)
            .execute()
            .value) ?? []
        return (
            likesRows.map { $0.spot_id.uuidString },
            bookmarkRows.map { $0.spot_id.uuidString }
        )
    }

    // MARK: - Like/Unlike
    func likeSpot(spotId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        withCurrentUserUUID { result in
            guard case .success(let uid) = result else {
                completion(result.map { _ in () })
                return
            }
            Task {
                do {
                    guard let sid = UUID(uuidString: spotId) else {
                        throw NSError(domain: "UserSpotService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid spot id"])
                    }
                    do {
                        try await supabase
                            .from("spot_likes")
                            .insert(SpotRefInsert(user_id: uid, spot_id: sid))
                            .execute()
                    } catch {
                        var current = try await self.fetchUserLists(for: uid).liked
                        if !current.contains(spotId) { current.append(spotId) }
                        try await supabase
                            .from("users")
                            .update(["liked_spots": current])
                            .eq("id", value: uid)
                            .execute()
                    }
                    await MainActor.run {
                        AnalyticsService.shared.trackUserAction("spot_liked", contentType: "spot", contentId: spotId)
                    }
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func unlikeSpot(spotId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        withCurrentUserUUID { result in
            guard case .success(let uid) = result else {
                completion(result.map { _ in () })
                return
            }
            Task {
                do {
                    guard let sid = UUID(uuidString: spotId) else {
                        throw NSError(domain: "UserSpotService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid spot id"])
                    }
                    do {
                        try await supabase
                            .from("spot_likes")
                            .delete()
                            .eq("user_id", value: uid)
                            .eq("spot_id", value: sid)
                            .execute()
                    } catch {
                        var current = try await self.fetchUserLists(for: uid).liked
                        current.removeAll { $0 == spotId }
                        try await supabase
                            .from("users")
                            .update(["liked_spots": current])
                            .eq("id", value: uid)
                            .execute()
                    }
                    await MainActor.run {
                        AnalyticsService.shared.trackUserAction("spot_unliked", contentType: "spot", contentId: spotId)
                    }
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Bookmark/Unbookmark
    func bookmarkSpot(spotId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        withCurrentUserUUID { result in
            guard case .success(let uid) = result else {
                completion(result.map { _ in () })
                return
            }
            Task {
                do {
                    guard let sid = UUID(uuidString: spotId) else {
                        throw NSError(domain: "UserSpotService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid spot id"])
                    }
                    do {
                        try await supabase
                            .from("spot_bookmarks")
                            .insert(SpotRefInsert(user_id: uid, spot_id: sid))
                            .execute()
                    } catch {
                        var current = try await self.fetchUserLists(for: uid).bookmarked
                        if !current.contains(spotId) { current.append(spotId) }
                        try await supabase
                            .from("users")
                            .update(["bookmarked_spots": current])
                            .eq("id", value: uid)
                            .execute()
                    }
                    await MainActor.run {
                        AnalyticsService.shared.trackUserAction("spot_saved", contentType: "spot", contentId: spotId)
                    }
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func unbookmarkSpot(spotId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        withCurrentUserUUID { result in
            guard case .success(let uid) = result else {
                completion(result.map { _ in () })
                return
            }
            Task {
                do {
                    guard let sid = UUID(uuidString: spotId) else {
                        throw NSError(domain: "UserSpotService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid spot id"])
                    }
                    do {
                        try await supabase
                            .from("spot_bookmarks")
                            .delete()
                            .eq("user_id", value: uid)
                            .eq("spot_id", value: sid)
                            .execute()
                    } catch {
                        var current = try await self.fetchUserLists(for: uid).bookmarked
                        current.removeAll { $0 == spotId }
                        try await supabase
                            .from("users")
                            .update(["bookmarked_spots": current])
                            .eq("id", value: uid)
                            .execute()
                    }
                    await MainActor.run {
                        AnalyticsService.shared.trackUserAction("spot_unsaved", contentType: "spot", contentId: spotId)
                    }
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Fetch liked/bookmarked spots
    func fetchUserSpotLists(completion: @escaping (_ liked: [String], _ bookmarked: [String]) -> Void) {
        guard let userId, let uid = UUID(uuidString: userId) else { completion([], []); return }
        Task {
            let lists = (try? await self.fetchUserLists(for: uid)) ?? (liked: [], bookmarked: [])
            completion(lists.liked, lists.bookmarked)
        }
    }

    // MARK: - Follow / Request Follow
    func follow(userId targetUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserId = userId,
              let follower = UUID(uuidString: currentUserId),
              let followee = UUID(uuidString: targetUserId) else {
            completion(.failure(NSError(domain: "No user", code: 0)))
            return
        }
        SpotLogger.log(UserSpotServiceLogs.followAttempt, details: ["followeeSuffix": String(targetUserId.suffix(8))])
        Task {
            do {
                struct FollowInsert: Encodable {
                    let follower_id: UUID
                    let followee_id: UUID
                }
                do {
                    try await supabase
                        .from("follows")
                        .insert(FollowInsert(follower_id: follower, followee_id: followee))
                        .execute()
                } catch {
                    if PostgresErrorDigest.isLikelyUniqueViolation(error) {
                        SpotLogger.log(UserSpotServiceLogs.followDuplicateIgnored, details: ["followeeSuffix": String(targetUserId.suffix(8))])
                    } else {
                        SpotLogger.log(UserSpotServiceLogs.followFailed, details: [
                            "followeeSuffix": String(targetUserId.suffix(8)),
                            "error": error.localizedDescription
                        ])
                        throw error
                    }
                }
                try await supabase
                    .from("follow_requests")
                    .delete()
                    .eq("requester_id", value: follower)
                    .eq("target_user_id", value: followee)
                    .eq("status", value: "pending")
                    .execute()
                await AuthorPrivacyCache.shared.onFollowRelationshipChanged(followeeUserId: targetUserId)
                SpotLogger.log(UserSpotServiceLogs.followSucceeded, details: ["followeeSuffix": String(targetUserId.suffix(8))])
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func requestFollow(userId targetUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserId = userId,
              let requester = UUID(uuidString: currentUserId),
              let target = UUID(uuidString: targetUserId) else {
            completion(.failure(NSError(domain: "No user", code: 0)))
            return
        }
        Task {
            do {
                struct FollowRequestInsert: Encodable {
                    let requester_id: UUID
                    let target_user_id: UUID
                    let status: String
                }
                try await supabase
                    .from("follow_requests")
                    .insert(FollowRequestInsert(requester_id: requester, target_user_id: target, status: "pending"))
                    .execute()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func getSocialLists(for userId: String? = nil, completion: @escaping (_ following: [String], _ requestedFollows: [String]) -> Void) {
        let uidString = userId ?? self.userId
        guard let uidString, let uuid = UUID(uuidString: uidString) else {
            completion([], [])
            return
        }
        Task {
            do {
                let (following, pendingTargets) = try await SocialGraphSupabase.socialLists(for: uuid)
                completion(following, pendingTargets)
            } catch {
                completion([], [])
            }
        }
    }

    func unfollow(userId targetUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserId = userId,
              let follower = UUID(uuidString: currentUserId),
              let followee = UUID(uuidString: targetUserId) else {
            completion(.failure(NSError(domain: "No user", code: 0)))
            return
        }
        SpotLogger.log(UserSpotServiceLogs.unfollowAttempt, details: ["followeeSuffix": String(targetUserId.suffix(8))])
        Task {
            do {
                try await supabase
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: follower)
                    .eq("followee_id", value: followee)
                    .execute()
                await AuthorPrivacyCache.shared.onFollowRelationshipChanged(followeeUserId: targetUserId)
                SpotLogger.log(UserSpotServiceLogs.unfollowSucceeded, details: ["followeeSuffix": String(targetUserId.suffix(8))])
                completion(.success(()))
            } catch {
                SpotLogger.log(UserSpotServiceLogs.unfollowFailed, details: [
                    "followeeSuffix": String(targetUserId.suffix(8)),
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    func cancelFollowRequest(userId targetUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserId = userId,
              let requester = UUID(uuidString: currentUserId),
              let target = UUID(uuidString: targetUserId) else {
            completion(.failure(NSError(domain: "No user", code: 0)))
            return
        }
        Task {
            do {
                try await supabase
                    .from("follow_requests")
                    .delete()
                    .eq("requester_id", value: requester)
                    .eq("target_user_id", value: target)
                    .eq("status", value: "pending")
                    .execute()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - New Paginated Likes/Bookmarks (array-column or relation-table backed)

    struct PaginatedSpotsResult {
        let spots: [Spot]
        let lastCursor: String?
        let hasMore: Bool
    }

    func fetchLikedSpots(pageSize: Int = 24, lastCursor: String? = nil) async throws -> PaginatedSpotsResult {
        guard let userId = userId, let uid = UUID(uuidString: userId) else {
            SpotLogger.log(UserSpotServiceLogs.noUserIdAvailable)
            throw NSError(domain: "No user", code: 0)
        }

        SpotLogger.log(UserSpotServiceLogs.fetchingLikedSpots, details: ["userId": userId])

        let lists = try await fetchUserLists(for: uid)
        let likedSpotIds = lists.liked
        let bookmarkedSpotIds = lists.bookmarked

        SpotLogger.log(UserSpotServiceLogs.foundLikedSpotIds, details: ["count": likedSpotIds.count])

        if likedSpotIds.isEmpty {
            SpotLogger.log(UserSpotServiceLogs.noLikedSpotsFound)
            return PaginatedSpotsResult(spots: [], lastCursor: nil, hasMore: false)
        }

        // For now, we'll use the array-based approach but sort by creation time
        // In a future migration, we could move to subcollections with timestamps
        // Fetch and mark each spot with like/save flags
        var spots = try await fetchSpotsByIds(likedSpotIds)
        let likedSet = Set(likedSpotIds)
        let savedSet = Set(bookmarkedSpotIds)
        spots = spots.map { s in
            var m = s
            if let id = m.id {
                m.isLiked = likedSet.contains(id)
                m.isSaved = savedSet.contains(id)
            }
            return m
        }

        // Sort by createdAt descending (most recent first)
        let sortedSpots = spots.sorted { (spot1, spot2) in
            (spot1.createdAt ?? Date.distantPast) > (spot2.createdAt ?? Date.distantPast)
        }

        // Simple pagination - return all spots for now since we're using arrays
        // In production with subcollections, you'd implement proper cursor-based pagination
        let hasMore = false // No pagination for array-based approach

        return PaginatedSpotsResult(
            spots: sortedSpots,
            lastCursor: nil,
            hasMore: hasMore
        )
    }

    func fetchBookmarkedSpots(pageSize: Int = 24, lastCursor: String? = nil) async throws -> PaginatedSpotsResult {
        guard let userId = userId, let uid = UUID(uuidString: userId) else {
            throw NSError(domain: "No user", code: 0)
        }

        let lists = try await fetchUserLists(for: uid)
        let bookmarkedSpotIds = lists.bookmarked
        let likedSpotIds = lists.liked

        if bookmarkedSpotIds.isEmpty {
            return PaginatedSpotsResult(spots: [], lastCursor: nil, hasMore: false)
        }

        // For now, we'll use the array-based approach but sort by creation time
        // Fetch and mark each spot with like/save flags
        var spots = try await fetchSpotsByIds(bookmarkedSpotIds)
        let savedSet = Set(bookmarkedSpotIds)
        let likedSet = Set(likedSpotIds)
        spots = spots.map { s in
            var m = s
            if let id = m.id {
                m.isSaved = savedSet.contains(id)
                m.isLiked = likedSet.contains(id)
            }
            return m
        }

        // Sort by createdAt descending (most recent first)
        let sortedSpots = spots.sorted { (spot1, spot2) in
            (spot1.createdAt ?? Date.distantPast) > (spot2.createdAt ?? Date.distantPast)
        }

        // Simple pagination - return all spots for now since we're using arrays
        // In production with subcollections, you'd implement proper cursor-based pagination
        let hasMore = false // No pagination for array-based approach

        return PaginatedSpotsResult(
            spots: sortedSpots,
            lastCursor: nil,
            hasMore: hasMore
        )
    }

    private func fetchSpotsByIds(_ spotIds: [String]) async throws -> [Spot] {
        guard !spotIds.isEmpty else { return [] }
        let uuids = spotIds.compactMap(UUID.init(uuidString:))
        let spots = try await SpotSupabaseRepository.fetchSpotsByIds(uuids)

        // Filter out blocked users' spots
        if let currentUserId = SpotAuthBridge.currentUserId,
           let uid = UUID(uuidString: currentUserId) {
            let blocked: [BlockRow] = (try? await supabase
                .from("user_blocks")
                .select("blocked_user_id")
                .eq("blocker_id", value: uid)
                .execute()
                .value) ?? []
            let blockedUsers = Set(blocked.map { $0.blocked_user_id.uuidString })

            return spots.filter { spot in
                guard let spotUserId = spot.userId else { return false }
                return !blockedUsers.contains(spotUserId)
            }
        }

        return spots
    }

}
