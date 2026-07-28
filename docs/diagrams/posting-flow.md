# Diagram: Posting and moderation

## Purpose

End-to-end create Spot through publish on the **Supabase** data plane.

## Audience

Engineering, safety.

## Current status

Matches `SpotPublishCoordinator`, `SpotSupabaseRepository`, and moderation migrations.

## Details

```mermaid
flowchart TD
  A[PostFlowViewModel submitPost] --> B[Validate auth, input, entitlement]
  B --> C[Persist local draft snapshot]
  C --> D[SpotPublishCoordinator.enqueue]
  D --> E[Reset composer and show global progress]
  E --> F[Insert pending media_assets row]
  F --> G[Upload JPEG to pending_images]
  G --> H[moderate-image Edge Function]
  H --> I{All assets approved?}
  I -->|No| J[Safe failure toast; recovery not guaranteed]
  I -->|Yes| K[publish_spot_with_approved_media_assets_v1 RPC]
  K --> L{RPC success?}
  L -->|No| M[Failure toast; approved assets may be unlinked]
  L -->|Yes| N[spotDidPostSuccess and optimistic feed insert]
```

## Related docs

- [../product/posting-flow.md](../product/posting-flow.md)
- [../engineering/data-plane.md](../engineering/data-plane.md)
- [../engineering/image-moderation.md](../engineering/image-moderation.md)

## Open questions / TODOs

- None.
