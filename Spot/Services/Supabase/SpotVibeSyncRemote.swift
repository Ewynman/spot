import Foundation

/// Thin Supabase loaders for vibe display mode (orchestration tested via injectable `loadRows`).
enum SpotVibeSyncRemote {
    /// Loads `spots.vibe_display_mode` for the given ids.
    /// - Parameter loadRows: Injectable for unit tests; defaults to Supabase.
    static func fetchDisplayModes(
        spotIds: [UUID],
        loadRows: (([UUID]) async throws -> [SpotVibeSyncHydration.ModeRow])? = nil
    ) async throws -> [UUID: VibeDisplayMode] {
        try await SpotVibeSyncHydration.displayModes(spotIds: spotIds) { ids in
            if let loadRows {
                return try await loadRows(ids)
            }
            return try await loadModeRowsFromSupabase(ids)
        }
    }

    private static func loadModeRowsFromSupabase(
        _ spotIds: [UUID]
    ) async throws -> [SpotVibeSyncHydration.ModeRow] {
        struct Row: Decodable { let id: UUID; let vibe_display_mode: String? }
        let rows: [Row] = try await supabase
            .from("spots")
            .select("id,vibe_display_mode")
            .in("id", values: spotIds)
            .execute()
            .value
        return rows.map { SpotVibeSyncHydration.ModeRow(id: $0.id, vibeDisplayMode: $0.vibe_display_mode) }
    }
}
