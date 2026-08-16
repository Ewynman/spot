# UGC moderation, reporting, blocking, and Terms

## Purpose

Defines the end-to-end system that satisfies Apple App Store **Guideline 1.2**
for user-generated content: zero-tolerance Terms acknowledgement, server-side
text + image filtering, in-app reporting, in-app blocking with instant content
removal, and a moderator queue with a 24-hour SLA.

## Audience

Engineers, safety / moderation owners, App Review reviewers consulting the
runbook in `docs/operations/app-store-review-notes.md`.

## Current status

Implemented in repository migrations and client code. Deployed production state must
be verified before each App Review submission; source control alone cannot prove it.

## Details

### Required UX surfaces (App Review)

| Surface | Behavior | iOS entry point |
| --- | --- | --- |
| Pre-auth Terms gate | Unchecked checkbox blocks Apple Sign-In, Get Started, Log in | `WelcomeView` + `TermsAgreementCheckboxView` |
| Registration-step Terms gate | Unchecked checkbox blocks "Continue" on the post-Sign-in-with-Apple username/profile-photo screen | `PostAuthSetupFlowView` + `TermsAgreementCheckboxView` |
| Post-auth update gate | Implemented but currently disabled pending production RPC verification | `RootView` → `TermsUpdateGateView` |
| Report a Spot | Reason picker, optional details, optional block toggle | `SpotCard` "ellipsis" menu → `ReportSheet` |
| Report a User | Reason picker, optional details, optional block toggle | `ProfileView` "ellipsis" menu (other user) → `ProfileReportSheet` |
| Block a User | Branded confirmation naming the user (`Block @username?`), then immediate feed removal | `ProfileView` ellipsis menu and `SpotCard` ellipsis menu; also reachable from `ReportSheet`/`ProfileReportSheet` toggle |
| Blocked Users management | List + unblock | `BlockedUsersView` (Settings) |

Both report flows surface a "**Submit**" alert acknowledging the report, then
fire `homeFeedLocallyRemove` so the offending content disappears immediately.

### Backend tables

All applied via Supabase migrations under `supabase/migrations/`.

| Table / function | Migration | Purpose |
| --- | --- | --- |
| `terms_versions` | `20260506210000_terms_acceptance_v1.sql` | Active legal versions + URLs (one `is_active = true` row at a time) |
| `user_terms_acceptances` | `20260506210000_terms_acceptance_v1.sql` | Per-user record of which version they agreed to, with device info |
| `moderation_events` | `20260506210100_moderation_events_v1.sql` | Append-only audit log; service-role only |
| `content_moderation_results` | `20260506210200_content_moderation_results_v1.sql` | Outcomes from text/image filters; service-role only |
| `spots.moderation_status` / `hidden_at` / `hidden_reason` | `20260506210300_spot_user_moderation_columns_v1.sql` | Spot-level moderation state used by `can_view_spot` |
| `users.account_status` / `moderation_status` | `20260506210300_spot_user_moderation_columns_v1.sql` | Account-level state used by `can_view_author` |
| `get_home_feed_v1` patch | `20260506210400_home_feed_rpc_moderation_filter_v1.sql` | Filter hidden / suspended content from feed |
| `text_token_normalize` / `text_contains_severe_blocked_terms` | `20260506210500_text_content_filter_v1.sql` | Deterministic token-based blocklist |
| `enforce_spot_text_moderation` / `enforce_user_text_moderation` triggers | `20260506210500_text_content_filter_v1.sql` | Reject violating content + log result row |
| `reports` extended columns | `20260506210600_reports_target_extension_v1.sql` | `target_type`, `target_id`, `status`, `priority`, review fields |
| `trg_log_moderation_event_for_report` / `trg_log_moderation_event_for_block` | `20260506210700_moderation_event_triggers_v1.sql` | Auto-populate `moderation_events` for any report/block |
| `submit_content_report` / `block_user_v1` / `record_terms_acceptance_v1` / `has_accepted_active_terms` | `20260506210800_report_block_terms_rpcs_v1.sql` | Typed RPCs the iOS client calls |
| `moderation_queue` view | `20260506210900_moderation_queue_view_v1.sql` | Open + reviewing reports ordered by priority for moderators |

### iOS service layer

| File | Responsibility |
| --- | --- |
| `Spot/Services/Moderation/ModerationService.swift` | Wraps `submit_content_report` and an available `block_user_v1` RPC path |
| `Spot/Services/Moderation/TermsAcceptanceService.swift` | Loads active terms, calls `record_terms_acceptance_v1` and `has_accepted_active_terms` |
| `Spot/Services/Moderation/PreAuthTermsAgreementStore.swift` | `@MainActor ObservableObject` for the pre-auth checkbox state (transient per launch) |
| `Spot/Models/Logs/ModerationServiceLogs.swift` | Structured logs |
| `Spot/Models/Logs/TermsAcceptanceLogs.swift` | Structured logs |

The post-auth updated-terms gate is temporarily disabled in `RootView` while
the production deployment of the terms-acceptance RPCs is investigated. The
pre-auth Terms of Use and Privacy Policy agreement remains visible. Re-enable
the gate only after `record_terms_acceptance_v1` and
`has_accepted_active_terms` are verified with an authenticated production user.

`ReportSheet` retains its legacy reasons and bridges to `ModerationReportReason`
through `ReportReason.moderationReason` so the existing entry point on
`SpotCard` keeps working while routing through the new RPC.

### Block flow guarantees

`AuthViewModel.blockUser(...)` performs a direct insert on `user_blocks`. The
`trg_log_moderation_event_for_block` trigger creates the matching
`moderation_events` row, ensuring **every** block (legacy or new) is auditable.
Client-side, callers post `Notification.Name.homeFeedLocallyRemove` with the
`authorUserId` so `HomepageView` immediately drops the blocked user's spots
without waiting for the next feed refresh. Server-side, `can_view_author`
already filters via `user_blocks`, so subsequent feed reads return nothing from
that author either direction.

Current report/profile UI paths use this direct-insert block implementation rather
than `ModerationService.blockUser`. Keep the database trigger and RLS path valid
for every insert route.

### Severe text blocklist

`text_contains_severe_blocked_terms` tokenizes input through
`text_token_normalize` (lowercase, alphanumeric splits) and compares against a
hardcoded array of severe terms. Hitting the list rejects the insert/update
with `RAISE EXCEPTION 'severe_blocked_term'` and writes a row to
`content_moderation_results` for audit. Triggers fire on:

- `INSERT OR UPDATE OF location_name, vibe_tag, description ON public.spots`
- `INSERT OR UPDATE OF username, display_name, bio ON public.users`

Tune the blocklist by editing the hardcoded array in the
`text_contains_severe_blocked_terms` SQL function and shipping a new migration.

### Moderator workflow (24-hour SLA)

Moderators use the `moderation_queue` view (service-role only):

```sql
select id, target_type, target_id, reported_user_id, reason, priority, created_at, details
from public.moderation_queue
order by priority desc, created_at asc;
```

To action a report:

1. Inspect the reported content via service-role queries (`spots`, `users`).
2. If the content violates Terms, set the appropriate moderation column:
   - `update spots set moderation_status = 'rejected', hidden_at = now(), hidden_reason = 'review_decision' where id = '...';`
   - `update users set account_status = 'suspended', moderation_status = 'rejected' where id = '...';`
3. Update the report: `update reports set status = 'actioned', reviewed_by = auth.uid(), reviewed_at = now(), action_taken = '...' where id = '...';`
4. The trigger on `reports` will append a new `moderation_events` row automatically.

The 24-hour SLA is operational, not enforced in code. Track by running:

```sql
select count(*) from public.moderation_queue
where created_at < now() - interval '24 hours';
```

### Logging

- iOS: `SpotLogger.log(ModerationServiceLogs....)` and `TermsAcceptanceLogs....` for every report, block, terms gate event, and gate failure.
- Postgres: `RAISE NOTICE` inside `submit_content_report` / `block_user_v1` if extended for forensics; per-row audit lives in `moderation_events`.

### Testing

| Test | File |
| --- | --- |
| Reason enum stability + log severity | `SpotTests/Services/Moderation/ModerationServiceTests.swift` |
| Pre-auth gate state machine | `SpotTests/Services/Moderation/PreAuthTermsAgreementStoreTests.swift` |
| Image scoring policy | `SpotTests/Utils/ModerationPolicyTests.swift` |

Networked RPC tests live in higher-level integration suites (run against a
seeded Supabase project) and are intentionally omitted from `SpotTests`.

## Related docs

- [`engineering/image-moderation.md`](image-moderation.md) — image-only moderation pipeline (Azure scores)
- [`engineering/database-and-rls.md`](database-and-rls.md) — RLS conventions
- [`engineering/networking-and-auth.md`](networking-and-auth.md) — auth gates
- [`operations/app-store-review-notes.md`](../operations/app-store-review-notes.md) — review submission notes
- [`product/support-and-policies.md`](../product/support-and-policies.md) — user-facing policy surfaces

## Open questions / TODOs

- **TODO**: ship the moderator dashboard UI on top of `moderation_queue` (currently service-role SQL only).
- **TODO**: extend the severe blocklist as new patterns emerge; consider externalizing to a `moderation_blocklist_terms` table for hot-reload.
- **TODO**: add automated synthetic monitoring that ensures `text_contains_severe_blocked_terms` rejects representative samples weekly.
