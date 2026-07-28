# Diagram: Image moderation sequence

## Purpose

Sequence for moderation-gated uploads.

## Audience

Engineering, safety.

## Current status

Verified for the Spot-image path. Profile avatars currently bypass this sequence.

## Details

```mermaid
sequenceDiagram
  participant User
  participant App
  participant Function as Moderation Function
  participant Azure as Azure Content Safety
  participant Storage as Supabase Storage
  participant DB as Supabase DB

  User->>App: Selects image
  App->>DB: Insert pending media_assets row
  App->>Storage: Upload to pending_images
  App->>Function: Send mediaAssetId with user JWT
  Function->>DB: Verify caller owns asset
  Function->>Storage: Read pending object
  Function->>Azure: Analyze image
  Azure-->>Function: Category severities
  alt Blocked
    Function->>DB: Mark rejected and record event
    Function->>Storage: Remove pending object
    Function-->>App: 422 approved=false
    App->>User: Show safe rejection message
  else Moderation unavailable
    Function->>DB: Mark failed where possible
    Function-->>App: 503 retryable
  else Approved
    Function->>Storage: Promote to approved bucket
    Function->>DB: Mark approved and record event
    Function-->>App: 200 approved=true
    App->>DB: Publish via approved-assets RPC
  end
```

## Related docs

- [../engineering/image-moderation.md](../engineering/image-moderation.md)

## Open questions / TODOs

- Route profile avatars through this sequence.
- Add cleanup for unlinked approved and failed assets.
