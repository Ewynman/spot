# Spot Production Readiness Audit Report

## Summary

This pass implemented the two functional fixes from the PRD (home feed variety after a single liked tag, and reliable follow state after navigation), added structured logging for feed diversity and follow writes, hardened follow-edge reads in `ProfileService`, enforced a unique index on `public.follows`, and documented findings. A lightweight production-leak grep was performed on `Spot/` Swift sources; no client service-role keys or committed JWTs were found.

## Production Leaks Searched

- Grep in `Spot/**/*.swift` for: `service_role`, `SUPABASE_SERVICE`, `Bearer ` (only `SpotSupabaseRepository` sets Bearer on outbound requests using the session token — not logged), obvious JWT blobs, `localhost` in app sources (not exhaustively re-listed here).
- Confirmed `UserSpotService` follow logging uses short `followeeSuffix` metadata rather than verbose session payloads.

## Issues Found

| Severity | Area | Issue | Fix |
| --- | --- | --- | --- |
| High | Home feed | Server-ranked page could repeat one vibe across the first window when personalization over-weighted a single tag. | Client `FeedDiversity` pass after `hydrateRows` in `FeedRepository.loadInitialV2`, using optional `user_feed_profiles` snapshot for low-signal detection; structured logs. |
| High | Profiles | Follow UI could disagree with Supabase after navigation or after races; follow-edge reads used `try?` and swallowed errors. | `ProfileView` reloads other users with `forceReload` on appear; `ProfileViewModel` refetches profile after successful follow/unfollow/request/cancel; `ProfileService` uses `do/catch` with error logs for follow queries; `AuthorPrivacyCache` invalidates following cache on graph changes. |
| Medium | Social graph | Duplicate `(follower_id, followee_id)` rows could exist without a DB unique index. | Migration `20260503120000_follows_unique_follower_followee.sql` + idempotent follow treats unique violations as success. |
| Low | On-device ranker | One liked tag produced a near-max vibe ratio. | Dirichlet-style smoothing in `FeedRanker.score` + unit test. |

## Security and Encryption Review

- **RLS**: `follows` policies already allow a viewer to `select` rows where they are follower or followee; `hasFollowEdge` matches that shape. No RLS weakening.
- **Client persistence**: No change to token storage; follow state is not cached in `UserDefaults`.
- **Logging**: Feed diversity logs aggregate counts only; follow logs avoid full session objects.

## Feed Variety Fix

- **Root cause**: Candidates are correct from `get_home_feed_v1`, but the first hydrated window could still be tag-heavy for low-signal accounts.
- **Implementation**: `FeedDiversity.diversifyHomeFeedPage` reorders the first items under caps (stricter when `user_feed_profiles`-derived signal count &lt; 10). Parallel fetch of profile snapshot in `FeedRepository` (non-blocking on failure).
- **Tests**: `SpotTests/Services/Feed/FeedDiversityTests.swift`, updated `FeedRankerTests`.

## Follow State Fix

- **Root cause**: Stale or optimistic-only UI without authoritative reload after mutations; silent failures on follow-edge `select`; following cache not invalidated after writes.
- **Implementation**: See table above + `PostgresErrorDigest` / duplicate follow handling in `UserSpotService`.
- **Supabase**: Unique index migration on `follows`.

## Supabase MCP Usage

- `list_projects` → Spot project `aeurigbbohyxvtsfiyul`.
- `apply_migration` **follows_unique_follower_followee**: dedupe `public.follows` duplicate `(follower_id, followee_id)` rows (by `ctid`) and `CREATE UNIQUE INDEX IF NOT EXISTS follows_follower_followee_uidx` — **applied successfully** to the linked Supabase project.

## Tests Added

- `SpotTests/Services/Feed/FeedDiversityTests.swift`
- `SpotTests/Utils/PostgresErrorDigestTests.swift`
- `SpotTests/Services/Feed/FeedRankerTests.swift` — `singleLikedTagDoesNotMaxOutVibeComponent`

## Remaining Risks

- **`get_home_feed_v1` SQL** is not in-repo; long-term personalization tuning should still happen server-side for consistency across clients.
- **Profile `loadUser` + `forceReload`**: concurrent rapid navigation could still race; monitor Crashlytics for rare profile load failures.
- **UI test** for follow-after-navigation was not added because it requires a deterministic second user in the synthetic session; manual QA or a dedicated staging fixture is recommended.
