import Foundation
import Supabase

struct SupabaseBookmarkCollectionsStore: BookmarkCollectionsPersisting {
    func insertCollection(userId: UUID, name: String) async throws -> UUID {
        struct InsertRow: Encodable { let user_id: UUID; let name: String; let sort_index: Int }
        struct IdRow: Decodable { let id: UUID }
        let row: IdRow = try await supabase.from("bookmark_collections").insert(InsertRow(user_id: userId, name: name, sort_index: 0)).select("id").single().execute().value
        return row.id
    }

    func assertOwnsCollection(userId: UUID, collectionId: UUID) async throws {
        struct CollCheck: Decodable { let id: UUID }
        let owners: [CollCheck] = try await supabase.from("bookmark_collections").select("id").eq("id", value: collectionId).eq("user_id", value: userId).limit(1).execute().value
        if owners.isEmpty { throw NSError(domain: "BookmarksCollectionsService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Collection not found"]) }
    }

    func nextSortIndex(collectionId: UUID) async throws -> Int {
        struct Row: Decodable { let sort_index: Int }
        let rows: [Row] = try await supabase.from("bookmark_collection_spots").select("sort_index").eq("collection_id", value: collectionId).order("sort_index", ascending: false).limit(1).execute().value
        return (rows.first?.sort_index ?? -1) + 1
    }

    func upsertSpotLink(collectionId: UUID, spotId: UUID, sortIndex: Int) async throws {
        struct LinkInsert: Encodable { let collection_id: UUID; let spot_id: UUID; let sort_index: Int }
        try await supabase.from("bookmark_collection_spots").upsert(LinkInsert(collection_id: collectionId, spot_id: spotId, sort_index: sortIndex), onConflict: "collection_id,spot_id", ignoreDuplicates: true).execute()
    }

    func deleteSpotLink(collectionId: UUID, spotId: UUID) async throws {
        try await supabase.from("bookmark_collection_spots").delete().eq("collection_id", value: collectionId).eq("spot_id", value: spotId).execute()
    }
}
