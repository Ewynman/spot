import Foundation
import Supabase

struct BookmarkCollection: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var spotIds: [String]
    var createdAt: Date?
}

final class BookmarksCollectionsService {
    static let shared = BookmarksCollectionsService()

    private let store: BookmarkCollectionsPersisting
    private let userIdProvider: () -> String?
    private let trackUserAction: SpotUserActionTracking

    init(
        store: BookmarkCollectionsPersisting = SupabaseBookmarkCollectionsStore(),
        userIdProvider: @escaping () -> String? = { SpotAuthBridge.currentUserId },
        trackUserAction: @escaping SpotUserActionTracking = SpotAnalyticsBridge.trackUserAction
    ) {
        self.store = store
        self.userIdProvider = userIdProvider
        self.trackUserAction = trackUserAction
    }

    private func uid() throws -> UUID {
        guard let raw = userIdProvider(), let id = UUID(uuidString: raw) else {
            throw NSError(domain: "No user", code: 0)
        }
        return id
    }

    private struct CollectionRow: Decodable {
        let id: UUID
        let name: String
        let sort_index: Int
        let created_at: String?
    }

    private struct CollectionSpotRow: Decodable {
        let collection_id: UUID
        let spot_id: UUID
        let sort_index: Int
    }

    func listCollections() async throws -> [BookmarkCollection] {
        let userId = try uid()
        let cols: [CollectionRow] = try await supabase
            .from("bookmark_collections")
            .select("id,name,sort_index,created_at")
            .eq("user_id", value: userId)
            .order("sort_index", ascending: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !cols.isEmpty else { return [] }

        let collectionIds = cols.map(\.id)
        let links: [CollectionSpotRow] = try await supabase
            .from("bookmark_collection_spots")
            .select("collection_id,spot_id,sort_index")
            .in("collection_id", values: collectionIds)
            .execute()
            .value

        var spotsByCollection: [UUID: [CollectionSpotRow]] = [:]
        for link in links {
            spotsByCollection[link.collection_id, default: []].append(link)
        }
        for cid in spotsByCollection.keys {
            spotsByCollection[cid]?.sort { $0.sort_index < $1.sort_index }
        }

        return cols.map { row in
            let ids = (spotsByCollection[row.id] ?? []).map { $0.spot_id.uuidString }
            return BookmarkCollection(
                id: row.id.uuidString,
                name: row.name,
                spotIds: ids,
                createdAt: row.created_at.flatMap { SpotSupabaseRepository.parseTimestamptz($0) }
            )
        }
    }

    func createCollection(name: String) async throws -> String {
        let userId = try uid()
        let collectionId = try await store.insertCollection(userId: userId, name: name)
        await trackUserAction("collection_created", "collection", collectionId.uuidString)
        return collectionId.uuidString
    }

    func addSpot(_ spotId: String, to collectionId: String) async throws {
        let userId = try uid()
        guard let coll = UUID(uuidString: collectionId),
              let spot = UUID(uuidString: spotId)
        else {
            throw NSError(domain: "BookmarksCollectionsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid id"])
        }

        try await store.assertOwnsCollection(userId: userId, collectionId: coll)
        let sortIndex = (try? await store.nextSortIndex(collectionId: coll)) ?? 0
        try await store.upsertSpotLink(collectionId: coll, spotId: spot, sortIndex: sortIndex)
        await trackUserAction("spot_added_to_collection", "spot", spotId)
    }

    func removeSpot(_ spotId: String, from collectionId: String) async throws {
        let userId = try uid()
        guard let coll = UUID(uuidString: collectionId),
              let spot = UUID(uuidString: spotId)
        else {
            throw NSError(domain: "BookmarksCollectionsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid id"])
        }

        try await store.assertOwnsCollection(userId: userId, collectionId: coll)
        try await store.deleteSpotLink(collectionId: coll, spotId: spot)
        await trackUserAction("spot_removed_from_collection", "spot", spotId)
    }

    func collectionIds(containing spotId: String) async throws -> Set<String> {
        let userId = try uid()
        guard let spot = UUID(uuidString: spotId) else {
            throw NSError(
                domain: "BookmarksCollectionsService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid spot id"]
            )
        }

        let collections = try await store.listOwnedCollectionIds(userId: userId)
        guard !collections.isEmpty else { return [] }

        let memberships = try await store.listMemberships(spotId: spot, in: collections)
        return Set(memberships.map(\.uuidString))
    }
}
