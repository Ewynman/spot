# App Store review notes

## Purpose

Information reviewers need for subscriptions, safety, and deep links.

## Audience

App Store review, internal release.

## Current status

Verify all **TODO** items before each submission.

## Details

### Where subscription is presented

Profile and Settings expose “Go Pro.” Feature-limit call sites route through `PaywallRouter`, and `RootView` presents `PaywallView`.

### Product ID (code)

- **`spotPro`** — yearly product in `Spot/Utils/SpotProProducts.swift`.

**App Store Connect pricing / metadata:** TODO: verify in App Store Connect.

### Demo credentials

**TODO: verify** whether Apple demo account is required for your review flow.

### Universal Links

Spot detail links use `https://spotapp.online/s/{spotId}` (and `www` variant). See [../engineering/universal-links.md](../engineering/universal-links.md).

### Moderation / safety (Guideline 1.2)

The repository implements Terms acknowledgement, server text filtering, reporting, blocking, and a moderator queue. Verify deployed backend state and the known media gaps below before asserting end-to-end compliance in submission notes.

| Requirement | Where to verify in the build |
| --- | --- |
| Terms of Use + Privacy Policy agreement before login/registration | `WelcomeView` shows an unchecked "I agree to..." checkbox that disables Apple Sign-In / Get Started / Log in until ticked. Cold launch always re-presents the gate. The same checkbox also appears on the post-Sign-in-with-Apple username/profile-photo screen (`PostAuthSetupFlowView`) and gates the "Continue" button there, so SIWA registrations cannot complete without explicit agreement. |
| Method for filtering objectionable content | Server-side: severe text blocklist triggers in `supabase/migrations/20260506210500_text_content_filter_v1.sql`; image moderation per [image-moderation.md](../engineering/image-moderation.md). |
| Mechanism to report objectionable content + abusive users | "Report Spot" — ellipsis menu on any spot card. "Report User" — ellipsis menu on another user's profile. Both flow through `submit_content_report` RPC and create a `moderation_events` audit row. |
| Mechanism to block abusive users | "Block User" — ellipsis menu on another user's profile and on a Spot card. Both present a branded confirmation that names the user (`Block @username?`). Report sheets can also block via toggle. Block writes to `user_blocks`, the `homeFeedLocallyRemove` notification removes the blocked user's spots from the feed instantly, and `can_view_author` filters server-side from then on. |
| Act on reports within 24 hours | `moderation_queue` view (service-role) prioritizes reports for the on-call moderator; SLA tracked by `select count(*) from moderation_queue where created_at < now() - interval '24 hours'`. |

Spot images go through Azure Content Safety scoring (`media_assets` / `media_moderation_events`) and rejected uploads receive non-graphic messaging. **Profile photos currently upload directly to the public `avatars` bucket and bypass moderation.** This conflicts with the product safety requirement and must be resolved before representing profile-image moderation as implemented to App Review.

### Privacy / support links

| Surface | URL / contact |
| --- | --- |
| Privacy Policy | `https://spotapp.online/privacy` |
| Terms of Use (EULA) | `https://spotapp.online/terms` |
| In-app support | Settings → Contact Support → `support@spotapp.online` |

Confirm App Store Connect metadata uses the same URLs and support email before each submission.

### Account deletion (Guideline 5.1.1(v))

Settings → Account settings → **Delete Account**:

- Email/password accounts: confirmation toggle + account password.
- Apple Sign In–only accounts: confirmation toggle + **Sign in with Apple** re-auth (no password setup required).

Server RPC: `delete_my_account` (see `supabase/migrations/`).

## Related docs

- [../product/pro-subscription.md](../product/pro-subscription.md)
- [../product/support-and-policies.md](../product/support-and-policies.md)

## Open questions / TODOs

- Fill in concrete review notes text file export if Apple asks for field-by-field copy: TODO: verify with owner.
