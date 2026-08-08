//
//  FeedProfileViewModel.swift
//  Spot
//
//  Loads the signed-in user's algorithm snapshot from
//  `public.user_feed_profiles` (RLS owner-only) and exposes it to the
//  "Your Algorithm" + debug screens. Also drives manual recomputes via
//  `recompute_my_feed_profile_v1`.
//

import Foundation

@MainActor
final class FeedProfileViewModel: ObservableObject {
    @Published private(set) var row: FeedProfileRow?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isRecomputing: Bool = false
    @Published var errorMessage: String?

    /// Convenience accessor for the embedded JSONB snapshot.
    var profile: FeedProfile? { row?.profile }

    /// Prefer the row-level timestamp (server-authoritative); fall back to
    /// the timestamp embedded in the JSONB if the row isn't yet hydrated.
    var lastComputedAt: Date? { row?.lastComputedAt ?? row?.profile.computedAt }

    var hasContent: Bool {
        FeedProfileContentPolicy.hasContent(profile)
    }

    /// Initial fetch from the cached profile row. Cheap and idempotent.
    /// Pass `force: true` to bypass the in-memory shortcut.
    func loadInitial(force: Bool = false) async {
        if isLoading { return }
        if !force, row != nil { return }
        isLoading = true
        errorMessage = nil
        do {
            row = try await FeedAPI.getMyFeedProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Forces a server-side recompute (self-only RPC) and re-reads the
    /// profile row so `lastComputedAt` reflects the new timestamp. If the
    /// read-back fails, the existing in-memory row is preserved and an error
    /// is surfaced so the UI can show a toast.
    func recompute() async {
        if isRecomputing { return }
        isRecomputing = true
        errorMessage = nil
        do {
            _ = try await FeedAPI.recomputeMyFeedProfile()
            do {
                if let r = try await FeedAPI.getMyFeedProfile() {
                    row = r
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRecomputing = false
    }
}
