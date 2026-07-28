# Terminology

## Purpose

Shared vocabulary for Spot product and engineering docs.

## Audience

Everyone contributing to or reviewing Spot.

## Current status

Aligned with in-app naming and common Supabase/iOS terms used in this repo.

## Details

| Term | Definition |
| --- | --- |
| **Spot** | A saved place recommendation: user post with media, place, vibe tags, and metadata. |
| **Vibe tag** | Discovery/category tag describing how a place feels or how you might use it. |
| **Creator** | The user who published a Spot. |
| **Feed** | Home scrolling list of Spots from `FeedRepository` / `get_home_feed_v1`. |
| **Map marker / pin** | Map annotation representing one or more Spots (clustering may apply). |
| **Spot drawer / bottom drawer** | Bottom sheet/card on the map showing the selected Spot preview. |
| **Draft** | Locally persisted in-progress Spot managed by `PostDraftStore` (autosave or user-saved). |
| **Pro** | Paid subscription tier; product ID `spotPro` (yearly) in `SpotProProducts.swift`. |
| **Universal Link** | `https` link on allowed hosts (e.g. `spotapp.online`) that opens the app via Associated Domains. |
| **Moderation** | Automated image safety checks (Azure Content Safety in DB migrations) before approved storage paths. |
| **RLS** | Row Level Security on Supabase Postgres and Storage; enforces access per authenticated user. |
| **Public / private profile** | Visibility of profile content to others; enforced server-side with client hints. |
| **Bookmark / save** | User saves a Spot for later (implementation: `UserSpotService` / Supabase tables—see code). |
| **Like** | User likes a Spot. |
| **Follow / following** | Social graph: follow relationship or pending follow request depending on privacy. |

## Related docs

- [overview.md](overview.md)
- [../engineering/universal-links.md](../engineering/universal-links.md)

## Open questions / TODOs

- None required for core terms; extend when new features ship.
