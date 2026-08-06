# Home feed

## Purpose

Describe the home feed’s role, how content is loaded, and privacy expectations.

## Audience

Product, engineering.

## Current status

Primary implementation: `Spot/Services/Feed/FeedRepository.swift` using Supabase RPC **`get_home_feed_v1`** (and status RPC **`get_home_feed_status_v1`** per comments in repository). On-device `FeedRanker` exists for tests/experiments.

## Details

### Experience

The **home feed** is the default discovery surface after launch: a ranked, paginated list of Spots tailored to the viewer.

After publishing, the completed Spot is inserted at the top of the current in-memory feed. The app does not immediately replace the entire feed with a new ranked page; a later user refresh remains authoritative.

### Ranking behavior

- **Server-side candidate set and ranking** via `get_home_feed_v1` (authoritative for production feed).
- **Client** hydrates rows, signs primary images for display, and manages `FeedLoadState` (initial load, load more, empty reasons, errors, refresh toasts).
- **`FeedDiversity`** — after hydration, the first home page is lightly reordered using `user_feed_profiles` signal strength so a single liked vibe does not fill the entire window when other tags exist in the page (`Spot/Services/Feed/FeedDiversity.swift`).
- **`FeedRanker`** — on-device scoring with tests but no production call site; it is not part of the shipped feed path.

### Signals (may influence ranking)

Exact weighting is **server-defined** in Postgres/RPC. The client passes `p_limit`, viewer latitude/longitude, a batch ID, and a seen-fallback flag. The repository does not contain the complete authoritative base definition of `get_home_feed_v1`, so exact weights cannot be reconstructed from this checkout.

Verified surrounding data and client inputs include:

- Creator identity and follow graph
- Vibe tags
- Location / distance
- Likes, bookmarks, follows
- Impressions / dedupe (`feed_impressions` mentioned in `FeedRepository`)

### Pagination and telemetry

The page size is 24. Pagination is not offset-based: each load-more request asks the server for another impression-aware batch and the client deduplicates IDs. Two consecutive empty load-more results, or a partial seen-fallback page, ends pagination.

`FeedEventService` records impression, two-second visibility, long dwell, and quick-skip events through `record_feed_event_v1`. The initial hydrated page is diversified on-device; subsequent pages preserve server order.

### Privacy and safety

- Private authors and blocks must be enforced **with RLS and server queries**; client filters are additive only.
- `AuthorPrivacyCache` supports client-side filtering and caching—must not replace server enforcement.

### Empty / error / loading

`FeedLoadState` distinguishes idle, loading initial/more, loaded, empty (with reason), and error while retaining prior items when possible. The pagination indicator is shown only during load-more so background or pull-to-refresh work does not shift the bottom of a visible list.

## Related docs

- [../engineering/architecture.md](../engineering/architecture.md)
- [../engineering/networking-and-auth.md](../engineering/networking-and-auth.md)
- [profiles-and-social.md](profiles-and-social.md)

## Open questions / TODOs

- Commit the authoritative base feed and map RPC definitions as migrations so ranking and visibility behavior can be reviewed from source control.
- Make home-feed image signing bucket-aware for moderated media; current batch signing assumes the legacy `spots` bucket.
