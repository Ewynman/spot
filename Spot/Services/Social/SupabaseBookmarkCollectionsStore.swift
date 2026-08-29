//
//  SupabaseBookmarkCollectionsStore.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Supabase

private struct BCInsert: Encodable { let user_id: UUID; let name: String; let sort_index: Int }
private struct BCID: Decodable { let id: UUID }
private struct BCSort: Decodable { let sort_index: Int }
private struct BCLink: Encodable { let collection_id: UUID; let spot_id: UUID; let sort_index: Int }
private struct BCMembership: Decodable { let collection_id: UUID }

struct SupabaseBookmarkCollectionsStore: BookmarkCollectionsPersisting {
    func insertCollection(userId: UUID, name: String) async throws -> UUID { let row: BCID = try await supabase.from("bookmark_collections").insert(BCInsert(user_id: userId, name: name, sort_index: 0)).select("id").single().execute().value; return row.id }
    func assertOwnsCollection(userId: UUID, collectionId: UUID) async throws { let owners: [BCID] = try await supabase.from("bookmark_collections").select("id").eq("id", value: collectionId).eq("user_id", value: userId).limit(1).execute().value; if owners.isEmpty { throw NSError(domain: "BookmarksCollectionsService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Collection not found"]) } }
    func nextSortIndex(collectionId: UUID) async throws -> Int { let rows: [BCSort] = try await supabase.from("bookmark_collection_spots").select("sort_index").eq("collection_id", value: collectionId).order("sort_index", ascending: false).limit(1).execute().value; return (rows.first?.sort_index ?? -1) + 1 }
    func upsertSpotLink(collectionId: UUID, spotId: UUID, sortIndex: Int) async throws { try await supabase.from("bookmark_collection_spots").upsert(BCLink(collection_id: collectionId, spot_id: spotId, sort_index: sortIndex), onConflict: "collection_id,spot_id", ignoreDuplicates: true).execute() }
    func deleteSpotLink(collectionId: UUID, spotId: UUID) async throws { try await supabase.from("bookmark_collection_spots").delete().eq("collection_id", value: collectionId).eq("spot_id", value: spotId).execute() }
    func listOwnedCollectionIds(userId: UUID) async throws -> [UUID] { let rows: [BCID] = try await supabase.from("bookmark_collections").select("id").eq("user_id", value: userId).execute().value; return rows.map(\.id) }
    func listMemberships(spotId: UUID, in collectionIds: [UUID]) async throws -> [UUID] { let rows: [BCMembership] = try await supabase.from("bookmark_collection_spots").select("collection_id").eq("spot_id", value: spotId).in("collection_id", values: collectionIds).execute().value; return rows.map(\.collection_id) }
}
