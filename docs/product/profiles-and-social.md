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

Public profiles use direct follow/unfollow actions. Private profiles use request, requested/cancel, accept, and deny states backed by `follows` and `follow_requests`.

`ProfileView` opens `FollowRequestsView` for the current user's pending requests and polls the pending count every eight seconds. `FollowRequestsService` paginates 24 requests at a time. `UserSpotService` mutates follow relationships, and `AuthorPrivacyCache` is invalidated after graph changes.

### Bookmarks and likes

Users save Spots (**bookmarks**) and react with **likes**; both feed ranking and profile grids.

Likes and bookmarks are loaded as complete ID sets rather than truly paginated grids. Pro users receive bookmark collections; free users use a flat bookmark grid and have a 50-bookmark cap.

### Privacy boundary

`ProfileService` reads `users_public`, determines whether the viewer is self, following, or pending, and only requests a private author's Spots when `canView` is true. Supabase RLS and `can_view_author` / `can_view_spot` remain authoritative.

## Related docs

- [terminology.md](terminology.md)
- [../engineering/database-and-rls.md](../engineering/database-and-rls.md)

## Open questions / TODOs

- Remote follow notifications are not implemented; see [notifications.md](../engineering/notifications.md).
- Likes and bookmark lists need real pagination for large accounts.
