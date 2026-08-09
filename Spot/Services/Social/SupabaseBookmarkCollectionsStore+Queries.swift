import Foundation
import Supabase

extension SupabaseBookmarkCollectionsStore {
    func listOwnedCollectionIds(userId: UUID) async throws -> [UUID] {
        struct IdRow: Decodable { let id: UUID }
        let rows: [IdRow] = try await supabase.from("bookmark_collections").select("id").eq("user_id", value: userId).execute().value
        return rows.map(\.id)
    }

    func listMemberships(spotId: UUID, in collectionIds: [UUID]) async throws -> [UUID] {
        struct MembershipRow: Decodable { let collection_id: UUID }
        let rows: [MembershipRow] = try await supabase.from("bookmark_collection_spots").select("collection_id").eq("spot_id", value: spotId).in("collection_id", values: collectionIds).execute().value
        return rows.map(\.collection_id)
    }
}
