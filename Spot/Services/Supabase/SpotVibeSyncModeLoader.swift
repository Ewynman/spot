//
//  SpotVibeSyncModeLoader.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Supabase fetch for `spots.vibe_display_mode` (thin I/O; mapping covered in `SpotVibeSyncHydration`).
enum SpotVibeSyncModeLoader {
    static func loadModeRows(_ spotIds: [UUID]) async throws -> [SpotVibeSyncHydration.ModeRow] {
        struct Row: Decodable { let id: UUID; let vibe_display_mode: String? }
        let rows: [Row] = try await supabase.from("spots").select("id,vibe_display_mode").in("id", values: spotIds).execute().value
        return rows.map { SpotVibeSyncHydration.ModeRow(id: $0.id, vibeDisplayMode: $0.vibe_display_mode) }
    }
}
