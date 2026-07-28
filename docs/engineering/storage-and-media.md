# Storage and media

## Purpose

Image pipeline buckets, upload flow, and signed URL usage for displaying media.

## Audience

Engineers working on posts, profiles, or moderation.

## Current status

Verified against the moderation migration, `SpotSupabaseRepository`, `FeedAPI`, `SpotImageGallery`, and `SupabaseUserService` on 2026-07-28.

## Details

### Buckets (from migration)

| Bucket id | Visibility | Purpose |
| --- | --- | --- |
| `pending_images` | Private | New uploads awaiting moderation |
| `approved_spot_images` | Private | Approved Spot imagery |
| `approved_profile_images` | Private | Intended approved profile photos; not used by current iOS upload path |
| `spots` | Private | Legacy Spot imagery and the bucket assumed by home-feed batch signing |
| `avatars` | Public | Current legacy profile avatar upload path |

### Spot media flow (summary)

1. Client inserts an owned **pending** `media_assets` row.
2. Client uploads bytes to the user's folder in `pending_images`.
3. Client invokes **`moderate-image`** with the media asset ID.
4. The Edge Function analyzes the image and, on approval, promotes it to `approved_spot_images`.
5. The client passes approved asset IDs to **`publish_spot_with_approved_media_assets_v1`**.

### Profile photos

The schema supports `kind = 'profile_image'` and `approved_profile_images`, but current iOS code does not use that path. `SupabaseUserService.uploadProfileAvatarJPEG` uploads directly to the public `avatars/{userId}/profile.jpg` path and returns a public URL.

This is a security and App Review gap. New profile-image work must migrate the client to pending upload, server moderation, and approved private storage; do not describe the current direct upload as compliant.

### Signed URLs

- Repository, profile, map, Search, optimistic-publish, and lazy gallery paths read `spot_images.storage_bucket` and create seven-day signed URLs.
- Home-feed batch signing currently calls `createSignedURLs` on `spots` for all rows. Moderated rows can live in `approved_spot_images`, so the feed requires a bucket-aware RPC/result contract or grouped signing.

### Failed publishes

There is no repository-defined scheduled cleanup for pending, failed, rejected, or approved-but-unlinked assets. A partial multi-image failure can leave approved unlinked assets.

Account deletion performs best-effort client cleanup for `avatars` and `spots`; it does not enumerate `pending_images`, `approved_spot_images`, or `approved_profile_images`. The database RPC deletes `media_assets` rows, but Storage objects are not database rows and may remain.

## Related docs

- [image-moderation.md](image-moderation.md)
- [supabase.md](supabase.md)

## Open questions / TODOs

- Define and implement retention/garbage collection for unlinked media and all moderation statuses.
- Make feed signing bucket-aware.
- Route profile avatars through the moderation pipeline.
- Extend account-deletion Storage cleanup to all owned buckets.
