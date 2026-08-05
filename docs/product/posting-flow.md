# Posting flow

## Purpose

Describe creating a Spot from the user’s perspective: media, place, vibes, draft, publish, moderation, and failures.

## Audience

Product, engineering, support.

## Current status

Publishing path uses Supabase only: `PostFlowViewModel` → `SpotPublishCoordinator` → `SpotSupabaseRepository.publishSpotFromDraft` (pending Storage upload, Edge Function moderation, RPC `publish_spot_with_approved_media_assets_v1`). See [../engineering/data-plane.md](../engineering/data-plane.md).

## Details

### Overview

User opens **Post** tab → multi-step composer (`Spot/Views/PostFlow`) → selects **photos** → **location** / place → **vibe tags** and **details** → **publish** or save work in progress.

### Media

Photos are chosen from the library or camera per system permissions (`Constants.UserDefaultsKeys` track permission prompts).

Free accounts can publish one photo and one vibe tag. Pro accounts can publish up to five photos and five vibe tags. The publish RPC independently enforces entitlement limits.

### Location

User searches by place, venue, or address, or chooses from nearby MapKit points of interest in `LocationSelectionView`. Nearby results use the latest shared Core Location fix, are ordered by distance, and start within 3 km. The user can expand the nearby search to 8 km, then confirm or adjust the pin before continuing.

### Vibe tags and caption

User picks from known tags and adds caption/details as the UI allows.

### Draft behavior

`PostDraftStore` persists drafts locally under Application Support, including a reserved `autosave` draft and user-saved drafts. Draft metadata is indexed locally; no server draft table is involved.

Submission persists a snapshot before JPEG encoding and queueing. The composer resets as soon as `SpotPublishCoordinator` accepts the job, allowing the user to leave the Post tab while the global publish banner reports progress.

### Publish and moderation

Every image for Spots must pass **moderation** before being treated as approved media. Client coordinates upload to **pending** storage and server-side moderation; publish completes via RPC when assets are approved.

### Failure states

| Condition | Expected UX (high level) |
| --- | --- |
| Not authenticated | Block publish; route to auth. |
| Upload fails | Error toast; a pre-queue local snapshot normally exists. |
| Moderation rejects | Safe message; do not publish. |
| Supabase insert / RPC fails | Error; preserve draft where applicable. |
| Network unavailable | Retryable error messaging; no offline publish queue. |

The coordinator has a 90-second timeout. A partial multi-image failure can leave approved but unlinked media assets. Current failure handling can also persist the already-reset composer over the earlier autosave, so the “saved to drafts” timeout copy does not guarantee full recovery. Treat this as a known implementation gap, not a recovery contract.

### Flow diagram

```mermaid
flowchart TD
  A[Start creating Spot] --> B{Authenticated?}
  B -->|No| C[Block and route to auth]
  B -->|Yes| D[Select media]
  D --> E[Select or confirm location]
  E --> F[Add vibe tags and details]
  F --> G{User action}
  G -->|Save draft| H[Persist draft locally]
  G -->|Publish| I[SpotPublishCoordinator enqueue]
  I --> J[Create pending media_assets row]
  J --> K[Upload to Supabase pending_images]
  K --> L[Edge Function moderate-image]
  L --> M{Approved?}
  M -->|No| N[Show safe failure]
  M -->|Yes| O[RPC publish_spot_with_approved_media_assets_v1]
  O --> P[Show success / optimistic feed update]
```

## Related docs

- [../engineering/image-moderation.md](../engineering/image-moderation.md)
- [../engineering/storage-and-media.md](../engineering/storage-and-media.md)
- [../diagrams/posting-flow.md](../diagrams/posting-flow.md)

## Open questions / TODOs

- Add orphan-media cleanup and make failed-publish draft recovery transactional before promising guaranteed recovery.
