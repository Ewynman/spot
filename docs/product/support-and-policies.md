# Support and policies

## Purpose

Point to in-app and external support, privacy, and safety policy surfaces.

## Audience

Support, review, engineering.

## Current status

In-app surfaces are implemented under **Profile → Settings**.

## Details

Spot exposes:

- **Contact support** — Settings → **Contact Support** → `mailto:support@spotapp.online` (`Constants.Legal.supportEmail`).
- **Privacy policy** — `https://spotapp.online/privacy` (signup, paywall, Settings → Legal).
- **Terms of Use** — `https://spotapp.online/terms` (signup, paywall, Settings → Legal).

Safety entry points:

- **Report a Spot** — `SpotCard` menu → `ReportSheet`.
- **Report a profile** — another user's profile menu → `ProfileReportSheet`.
- **Block a user** — profile or report confirmation; the feed removes that author's Spots immediately.
- **Manage blocks** — Settings → `BlockedUsersView`.
- **Delete account** — Settings, confirmation, and password or Sign in with Apple reauthentication.

## Related docs

- [../operations/app-store-review-notes.md](../operations/app-store-review-notes.md)
- [../operations/incident-response.md](../operations/incident-response.md)
- [../engineering/ugc-moderation.md](../engineering/ugc-moderation.md)

## Open questions / TODOs

- External website availability remains an operational check even though the configured URLs are verified in code.
