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
    private init() {}

    private func uid() throws -> UUID {
        guard let raw = SpotAuthBridge.currentUserId, let id = UUID(uuidString: raw) else {
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
        struct InsertRow: Encodable {
            let user_id: UUID
            let name: String
            let sort_index: Int
        }
        let row: CollectionRow = try await supabase
            .from("bookmark_collections")
            .insert(InsertRow(user_id: userId, name: name, sort_index: 0))
            .select("id,name,sort_index,created_at")
            .single()
            .execute()
            .value
        return row.id.uuidString
    }

    func addSpot(_ spotId: String, to collectionId: String) async throws {
        let userId = try uid()
        guard let coll = UUID(uuidString: collectionId),
              let spot = UUID(uuidString: spotId)
        else {
            throw NSError(domain: "BookmarksCollectionsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid id"])
        }

        struct CollCheck: Decodable { let id: UUID }
        let owners: [CollCheck] = try await supabase
            .from("bookmark_collections")
            .select("id")
            .eq("id", value: coll)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        guard !owners.isEmpty else {
            throw NSError(domain: "BookmarksCollectionsService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])
        }

        struct LinkInsert: Encodable {
            let collection_id: UUID
            let spot_id: UUID
            let sort_index: Int
        }

        let maxSort: Int = (try? await maxSortIndex(collectionId: coll)) ?? -1
        try await supabase
            .from("bookmark_collection_spots")
            .insert(LinkInsert(collection_id: coll, spot_id: spot, sort_index: maxSort + 1))
            .execute()
    }

    private func maxSortIndex(collectionId: UUID) async throws -> Int {
        struct Row: Decodable { let sort_index: Int }
        let rows: [Row] = try await supabase
            .from("bookmark_collection_spots")
            .select("sort_index")
            .eq("collection_id", value: collectionId)
            .order("sort_index", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first?.sort_index ?? -1
    }

    func removeSpot(_ spotId: String, from collectionId: String) async throws {
        let userId = try uid()
        guard let coll = UUID(uuidString: collectionId),
              let spot = UUID(uuidString: spotId)
        else {
            throw NSError(domain: "BookmarksCollectionsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid id"])
        }

        struct CollCheck: Decodable { let id: UUID }
        let owners: [CollCheck] = try await supabase
            .from("bookmark_collections")
            .select("id")
            .eq("id", value: coll)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        guard !owners.isEmpty else {
            throw NSError(domain: "BookmarksCollectionsService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])
        }

        try await supabase
            .from("bookmark_collection_spots")
            .delete()
            .eq("collection_id", value: coll)
            .eq("spot_id", value: spot)
            .execute()
    }
}
