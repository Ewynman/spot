# Documentation audit — 2026-07

## Purpose

Record the July 2026 code-to-documentation audit, what was verified from source, and what still requires deployed-system or product-owner confirmation.

## Scope

The audit covered repository Markdown, app launch/auth/navigation, onboarding, feed, map, Search, profile/social, publishing, media moderation, Supabase/RLS, deep links, Pro, notifications, testing, CI/CD, and release operations.

## Verified and refreshed

| Area | Source of truth reviewed |
| --- | --- |
| Launch/auth/root navigation | `AppDelegate`, `SpotApp`, `RootView`, `AuthViewModel`, auth views and credential stores |
| First-run onboarding | `SpotFirstRunOnboardingManager`, `BottomTabNavigationView` |
| Feed and map | `FeedRepository`, `FeedAPI`, `FeedDiversity`, `MapViewModel`, `MapViewportLoader`, drawer policy |
| Search and Spot presentation | `SearchViewModel`, `SearchService`, `SpotSearchDataSource`, shared `SpotCard` |
| Profiles/social/privacy | `ProfileViewModel`, `ProfileService`, follow services, `AuthorPrivacyCache` |
| Publishing/media | `PostFlowViewModel`, `PostDraftStore`, `SpotPublishCoordinator`, `SpotSupabaseRepository` |
| Moderation and RLS | Edge Function source and committed migrations |
| Deep links and Pro | `DeepLinkRouter`, `DeepLinkState`, `SubscriptionManager`, feature gates |
| Notifications | `NotificationService`, `AppDelegate`, event consumers |
| Build/release | Xcode project, test plans, scripts, and GitHub Actions workflows |

## Waiting on external verification

These cannot be closed from repository code:

- staging and production migration parity;
- deployed Edge Function versions and secret presence;
- live Auth email-confirmation templates/provider settings;
- AASA responses from both production hosts;
- App Store Connect product metadata, pricing, agreements, and review credentials;
- branch protection and required-check configuration;
- production dashboard links and operational ownership.

## Confirmed implementation gaps

These are not documentation TODOs; they require code/backend work:

1. Profile avatars bypass image moderation and use the public `avatars` bucket.
2. Home-feed batch signing assumes `spots`, while moderated images can use `approved_spot_images`.
3. Failed publish draft recovery is not transactional and approved unlinked media can remain.
4. Moderated Storage buckets are not fully covered by client account-deletion cleanup.
5. Notification delivery is local-only; social delivery and action navigation are incomplete.
6. The Pro map Following filter receives no followed-user IDs.
7. Complete base definitions for some feed/map RPCs are absent from migrations.
8. App Check is linked but not initialized.

## Documentation decisions

- Current behavior is documented separately from target requirements.
- Known safety gaps are explicit in review-facing docs.
- `docs/engineering/runtime-flows.md` is the concise code path map.
- Product feature pages own user-facing behavior; engineering pages own boundaries and failure modes; diagrams mirror actual flows.
- Time-bound PRDs and audits may retain future requirements, but their status must not contradict current code.

## Follow-up checklist

- [ ] Resolve profile-image moderation before claiming full image moderation to App Review.
- [ ] Export missing authoritative RPC definitions into migrations.
- [ ] Verify both Supabase projects and update this audit with evidence.
- [ ] Validate live AASA and release metadata.
- [ ] Add automated Markdown link validation.
- [ ] Re-audit after the pending auth, safety, or release work lands.

## Related docs

- [../engineering/runtime-flows.md](../engineering/runtime-flows.md)
- [../engineering/image-moderation.md](../engineering/image-moderation.md)
- [../engineering/supabase-environment-strategy.md](../engineering/supabase-environment-strategy.md)
- [documentation-maintenance.md](documentation-maintenance.md)
