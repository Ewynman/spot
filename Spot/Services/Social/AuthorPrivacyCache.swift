//
//  AuthorPrivacyCache.swift
//  Spot
//
//  Session-scoped, in-memory cache for author privacy and follow state (Supabase-backed).
//

import Foundation
import Supabase

/// Keyed by authorId. Entry: `isPrivate`, `isFollowedByViewer`, `lastCheckedAt`.
actor AuthorPrivacyCache {
    struct Entry {
        var isPrivate: Bool
        var isFollowedByViewer: Bool
        var lastCheckedAt: Date
    }

    static let shared = AuthorPrivacyCache()
    private init() {}

    private let ttl: TimeInterval = 60 * 5 // 5 minutes

    private var authorIdToEntry: [String: Entry] = [:]
    private var cachedFollowing: Set<String> = []
    private var followingFetchedAt: Date = .distantPast
    private var cachedBlockedUsers: Set<String> = []
    private var blockedFetchedAt: Date = .distantPast

    // MARK: Public API

    func clear() {
        authorIdToEntry.removeAll()
        cachedFollowing.removeAll()
        followingFetchedAt = .distantPast
        cachedBlockedUsers.removeAll()
        blockedFetchedAt = .distantPast
    }

    func invalidate(authorId: String) {
        authorIdToEntry.removeValue(forKey: authorId)
    }

    /// Call after a successful follow/unfollow so following-based privacy and map filters refresh.
    func onFollowRelationshipChanged(followeeUserId: String) {
        authorIdToEntry.removeValue(forKey: followeeUserId)
        followingFetchedAt = .distantPast
    }

    /// Preload cache for the provided authors in a single batched pass.
    func warm(authorIds: Set<String>) async {
        guard !authorIds.isEmpty else { return }

        async let _ = refreshFollowingIfNeeded()
        async let _ = refreshBlockedIfNeeded()

        let now = Date()
        var missing: [String] = []
        for id in authorIds {
            if let entry = authorIdToEntry[id], now.timeIntervalSince(entry.lastCheckedAt) < ttl {
                continue
            }
            missing.append(id)
        }

        guard !missing.isEmpty else { return }

        SpotLogger.log(AuthorPrivacyCacheLogs.cacheWarm, details: ["authors": missing.count])

        let chunks: [[String]] = stride(from: 0, to: missing.count, by: 10).map {
            Array(missing[$0..<min($0 + 10, missing.count)])
        }

        struct UserPrivRow: Decodable {
            let id: UUID
            let is_private: Bool
        }

        var combined: [String: Entry] = [:]
        for chunk in chunks {
            let uuids = chunk.compactMap { UUID(uuidString: $0) }
            guard !uuids.isEmpty else { continue }
            do {
                let rows: [UserPrivRow] = try await supabase
                    .from(SupabaseTableName.usersPublic)
                    .select("id,is_private")
                    .in("id", values: uuids)
                    .execute()
                    .value
                let nowRow = Date()
                let returned = Set(rows.map { $0.id.uuidString })
                for r in rows {
                    combined[r.id.uuidString] = Entry(
                        isPrivate: r.is_private,
                        isFollowedByViewer: false,
                        lastCheckedAt: nowRow
                    )
                }
                for uid in Set(chunk).subtracting(returned) {
                    combined[uid] = Entry(isPrivate: true, isFollowedByViewer: false, lastCheckedAt: nowRow)
                }
            } catch {
                SpotLogger.log(AuthorPrivacyCacheLogs.cacheWarmFailed, details: ["count": chunk.count, "error": error.localizedDescription])
            }
        }

        let now2 = Date()
        for (uid, base) in combined {
            let followed = cachedFollowing.contains(uid)
            authorIdToEntry[uid] = Entry(isPrivate: base.isPrivate, isFollowedByViewer: followed, lastCheckedAt: now2)
        }
    }

    func isAllowed(authorId: String) -> Bool? {
        guard let viewerId = SpotAuthBridge.currentUserId else { return true }
        if viewerId == authorId { return true }

        if cachedBlockedUsers.contains(authorId) { return false }

        if let entry = authorIdToEntry[authorId], Date().timeIntervalSince(entry.lastCheckedAt) < ttl {
            if !entry.isPrivate { return true }
            return entry.isFollowedByViewer
        }

        SpotLogger.log(AuthorPrivacyCacheLogs.cacheMiss, details: ["authorId": authorId])
        return nil
    }

    func filter(spots: [Spot]) async -> [Spot] {
        guard !spots.isEmpty else { return spots }
        let viewerId = SpotAuthBridge.currentUserId
        let authors = Set(spots.compactMap { $0.userId })
        await warm(authorIds: authors)

        var filtered: [Spot] = []
        for s in spots {
            guard let author = s.userId else { continue }
            if let v = viewerId, v == author { filtered.append(s); continue }
            if cachedBlockedUsers.contains(author) {
                SpotLogger.log(AuthorPrivacyCacheLogs.privacyDropBlockedUser, details: ["spotId": s.id ?? "nil", "authorId": author])
                continue
            }
            if let allowed = isAllowed(authorId: author) {
                if allowed { filtered.append(s) } else {
                    SpotLogger.log(AuthorPrivacyCacheLogs.privacyDropPrivateNotFollowed, details: ["spotId": s.id ?? "nil", "authorId": author])
                }
            } else {
                SpotLogger.log(AuthorPrivacyCacheLogs.privacyDropUnknownAuthor, details: ["spotId": s.id ?? "nil", "authorId": author])
            }
        }
        return filtered
    }

    // MARK: Internals

    private func refreshFollowingIfNeeded() async {
        guard let viewerId = SpotAuthBridge.currentUserId, let uid = UUID(uuidString: viewerId) else { return }
        if Date().timeIntervalSince(followingFetchedAt) < ttl { return }
        do {
            let ids = try await SocialGraphSupabase.followingIds(followerId: uid)
            cachedFollowing = Set(ids)
            followingFetchedAt = Date()
        } catch {
            SpotLogger.log(AuthorPrivacyCacheLogs.refreshFollowingFailed, details: ["error": error.localizedDescription])
        }
    }

    private func refreshBlockedIfNeeded() async {
        guard let viewerId = SpotAuthBridge.currentUserId, let uid = UUID(uuidString: viewerId) else { return }
        if Date().timeIntervalSince(blockedFetchedAt) < ttl { return }
        do {
            struct Row: Decodable { let blocked_user_id: UUID }
            let rows: [Row] = try await supabase
                .from("user_blocks")
                .select("blocked_user_id")
                .eq("blocker_id", value: uid)
                .execute()
                .value
            cachedBlockedUsers = Set(rows.map { $0.blocked_user_id.uuidString })
            blockedFetchedAt = Date()
        } catch {
            SpotLogger.log(AuthorPrivacyCacheLogs.refreshBlockedUsersFailed, details: ["error": error.localizedDescription])
        }
    }
}
