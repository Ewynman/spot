# Profiles and social

## Purpose

Describe profiles, follows, bookmarks, and privacy from a product angle.

## Audience

Product, engineering, support.

## Current status

Implementation spread across `Spot/Views/Profile`, `ProfileViewModel`, `ProfileService`, follow-request migrations under `supabase/migrations/`, and `AuthorPrivacyCache`.

## Details

### Profile

A **profile** shows a user’s identity, Spots, collections/bookmarks as implemented, and social actions (follow, etc.).

When a profile has no visible Spots, the Spots area explains the empty state. On the current user's own profile, it also offers a **Post a Spot** action that opens the Post tab. Other users' empty profiles do not show that action, and private profiles explain that following is required to view their Spots.

### Public vs private

Some profiles or content may be **private** to non-followers or pending requests. Visibility is enforced with **Supabase RLS**; the client reflects “unavailable” or limited UI when appropriate.

### Follow / following

Follow graph and optional **follow requests** are backed by Postgres (see migrations such as `20260503100000_follow_requests_revoke_client_update.sql`). UX: request, accept, revoke—**TODO: verify** exact screens.

### Bookmarks and likes

Users save Spots (**bookmarks**) and react with **likes**; both feed ranking and profile grids.

## Related docs

- [terminology.md](terminology.md)
- [../engineering/database-and-rls.md](../engineering/database-and-rls.md)

## Open questions / TODOs

- Map each social action to concrete tables/RPCs in a future pass: TODO: verify against `SpotSupabaseRepository` and migrations.
