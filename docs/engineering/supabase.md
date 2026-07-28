# Supabase

## Purpose

Explain how Supabase fits into Spot: Auth, Postgres, Storage, Edge Functions, and migrations.

## Audience

Engineers touching data or backend.

## Current status

Client: `Spot/Supabase/Supabase.swift`, `SpotSupabaseRepository`. Schema evolution: `supabase/migrations/*.sql`.

## Details

### Role in architecture

Supabase is the **primary backend**: authentication, relational data for users/spots/social graph, storage for images, and RPCs such as **`get_home_feed_v1`** and **`publish_spot_with_approved_media_assets_v1`**.

**Policy:** Firebase must not be used for the application data plane. See [data-plane.md](data-plane.md).

### Auth

Supabase Auth issues JWTs consumed by the Swift client; `public.users` and related tables tie profiles to `auth.users`.

### Database

Postgres with RLS policies defined in migrations (e.g. `20260502120000_security_sweep_rls_part_1.sql`, moderation migration).

### Storage

Private buckets for pending and approved images (`pending_images`, `approved_spot_images`, `approved_profile_images`) per `20260504100000_image_moderation_azure_v1.sql`, plus legacy `spots` and public `avatars` paths still used by client code.

### Edge Functions

The versioned Edge Function is **`moderate-image`** under `supabase/functions/moderate-image/`. Deployment and secret presence must be verified independently in each project.

### Key RPCs and functions

| Function | Role |
| --- | --- |
| `get_home_feed_v1`, `get_home_feed_status_v1` | Ranked feed and empty/caught-up state |
| `get_map_spots_v1` | Viewport discovery |
| `record_feed_event_v1`, `recompute_my_feed_profile_v1` | Feed telemetry and profile recomputation |
| `publish_spot_with_approved_media_assets_v1` | Atomic publish from approved assets |
| `submit_content_report` | Authenticated UGC report |
| `delete_my_account` | Account and relational-data deletion |
| `sync_current_user_v1` | Authenticated profile synchronization |
| `is_username_available` | Privacy-limited signup availability result |
| `record_terms_acceptance_v1`, `has_accepted_active_terms` | Terms version state |

Some base feed/map RPC definitions are not fully represented in committed migrations. Treat that as a reproducibility gap.

### Local vs production

- **Local DEBUG and Firebase distribution**: staging project.
- **TestFlight and App Store**: production project injected by the release workflow.
- A local Supabase stack is not part of the documented standard path; use staging unless the team deliberately establishes one.

### MCP

Supabase changes require reviewed SQL under `supabase/migrations/` and application through the Supabase MCP to the linked project. Test staging before production.

### Safety for schema changes

1. Never weaken RLS without security review.
2. Prefer additive migrations and backfills.
3. Test policies with non-owner sessions.

## Related docs

- [data-plane.md](data-plane.md)
- [database-and-rls.md](database-and-rls.md)
- [storage-and-media.md](storage-and-media.md)
- [image-moderation.md](image-moderation.md)

## Open questions / TODOs

- Export or recreate missing authoritative base feed/map function definitions as migrations.
