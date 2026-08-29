//
//  SupabaseSpotBookmarkStore.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Supabase

struct SupabaseSpotBookmarkStore: SpotBookmarkPersisting {
    func upsertBookmark(userId: UUID, spotId: UUID) async throws {
        struct Row: Encodable { let user_id: UUID; let spot_id: UUID }
        try await supabase.from("spot_bookmarks").upsert(Row(user_id: userId, spot_id: spotId), onConflict: "user_id,spot_id", ignoreDuplicates: true).execute()
    }

    func removeSavedSpot(spotId: UUID) async throws {
        try await supabase.rpc("remove_saved_spot_v1", params: ["p_spot_id": spotId]).execute()
    }
}
