# Authentication reliability release PRD

## Purpose

Make account creation, email verification, login, and session restoration reliable enough for release. Authentication is a release-blocking user journey: a user must be able to create an account, verify it, return later, and install an in-place update without being incorrectly rejected or unexpectedly signed out.

## Status

- **Priority:** P0 release blocker
- **Owner:** TODO
- **Target:** Before release candidate approval
- **Last reviewed:** 2026-07-27
- **Evidence basis:** Repository audit. Live staging and production Supabase configuration still requires verification.

## Problem statement

Current tester reports:

1. Installing a new app version appears to sign the user out.
2. Credentials for a newly created account do not work.
3. Every attempted username is reported as taken.

The repository audit found code paths that can produce all three symptoms:

- `FreshInstallDetector` deliberately signs out a valid Keychain session when its UserDefaults install marker is absent.
- Debug builds use staging while distributed Release builds are intended to use production. Sessions and accounts are scoped to the Supabase project, so switching environments looks like a logout and credentials created in one environment do not exist in the other.
- Username availability treats every RPC error as `false`, which the UI presents as “Username is already taken.”
- The required `is_username_available` and `resolve_login_email` RPC definitions are not present in committed migrations.
- Pending email verification exists only in memory. Relaunching before OTP completion loses the verification screen.
- Login collapses unconfirmed-email and most other authentication failures into “Incorrect email/username or password.”

These findings establish credible code-level causes but do not prove which one occurred in a specific production incident. Runtime telemetry and live Supabase checks are required.

## Goals

- Preserve a valid session across an in-place update using the same bundle identifier and Supabase environment.
- Make environment mismatches visible in diagnostics and impossible in release artifacts.
- Make username availability accurate and distinguish “taken” from service failure.
- Make signup, six-digit OTP verification, relaunch, and subsequent login a recoverable end-to-end flow.
- Present actionable, privacy-safe errors for invalid credentials, unverified email, connectivity failures, and unavailable backend services.
- Ensure all client-required database functions are versioned, deployed, permissioned, and tested in staging and production.
- Add automated coverage and release checks for the critical authentication journeys.

## Non-goals

- Redesigning the full onboarding experience.
- Changing Sign in with Apple behavior except where shared session handling is affected.
- Adding social login providers.
- Broad profile or feed architecture changes.
- Exposing whether a private email address has an account.

## Current behavior and evidence

### Session restoration and updates

- The Supabase SDK stores its session in Keychain and emits the local session at startup: `Spot/Supabase/Supabase.swift`.
- `AuthViewModel` restores authentication from `supabase.auth.authStateChanges`: `Spot/Services/Auth/AuthViewModel.swift`.
- `FreshInstallDetector.handleFreshInstall()` checks a UserDefaults marker. If the marker is missing but Keychain still contains a session, it calls `supabase.auth.signOut()`: `Spot/Utils/FreshInstallDetector.swift`.
- Debug builds select staging. Release builds select production or an injected plist configuration. Different Supabase projects have different account stores and Keychain session keys: `Spot/Supabase/Supabase.swift`.
- Firebase App Distribution and TestFlight workflows intend to inject production configuration: `.github/workflows/deploy.yml` and `.github/workflows/testflight.yml`.

A genuine in-place update should preserve both UserDefaults and Keychain. Therefore, repeated logout on every update suggests at least one of:

1. The distribution process behaves like delete/reinstall.
2. The build changes bundle identity, app container, signing context, or Supabase project.
3. Session refresh fails and Supabase emits a signed-out event.
4. The install marker is being lost independently of Keychain.

### Username availability

`SignupView.validateAndSignUp()` asks `AuthViewModel.isUsernameAvailable()`. That method catches every error and returns `false`; the view always translates `false` to “Username is already taken”:

- `Spot/Views/Auth/SignupView.swift`
- `Spot/Services/Auth/AuthViewModel.swift`

The client invokes `is_username_available`, but no definition is committed under `supabase/migrations/`. This can make every username appear taken when the function is missing, not deployed, not granted to `anon`, or temporarily unavailable.

### Newly created account login

- Email/password signup requires a six-digit signup OTP in the current UI.
- Pending verification email and state are memory-only in `AuthViewModel`.
- If the app terminates before verification, relaunch returns to the signed-out welcome flow.
- Attempting login before confirmation can return Supabase’s email-not-confirmed error, but `LoginView` presents the generic incorrect-credentials message.
- Username login invokes `resolve_login_email`, whose definition is also absent from committed migrations.
- The profile synchronization RPC is versioned in `20260702120000_sync_current_user_security_definer_v1.sql`, but deployment to both live projects must be confirmed.

## Product requirements

### R1 — Session continuity

1. A user with a valid session remains authenticated after upgrading from the previous supported build to the release candidate when bundle identifier and Supabase environment are unchanged.
2. Authentication startup must resolve to signed in, signed out, or a recoverable error state; it must not remain indefinitely on the launch screen for an expired session.
3. The app must record a privacy-safe reason for each transition to signed out:
   - explicit user logout
   - account deletion
   - reinstall policy
   - missing local session
   - refresh token rejected
   - environment mismatch
   - unknown SDK sign-out
4. Release builds must fail CI if the embedded Supabase project does not match the approved production project.
5. The delete/reinstall policy must be explicitly approved. Recommended launch behavior is:
   - preserve valid sessions for in-place updates;
   - treat a confirmed delete/reinstall separately;
   - if security requires logout after reinstall, document and test it rather than classifying it as an update.

### R2 — Username availability

1. Add `is_username_available` through a committed Supabase migration and deploy the same migration to staging and production.
2. Define one canonical normalization and validation contract shared by the client and database, including case handling and allowed punctuation.
3. Grant only the minimum permission required for unauthenticated signup checks and retain RLS/security boundaries.
4. Return distinct application outcomes:
   - available
   - taken
   - invalid
   - temporarily unavailable
5. Network, RPC, permission, or decoding failures must never be shown as “Username is already taken.”
6. The signup action must prevent duplicate submissions while the availability request is in progress.
7. Availability is advisory; final username uniqueness must be enforced atomically by the database.

### R3 — Signup and email verification

1. Production and staging Supabase Auth must use the same approved email-confirmation mode.
2. If the app uses a six-digit OTP, the configured email template must include the OTP token and the app must not depend on a magic-link-only callback.
3. Pending verification state must survive app termination and relaunch without storing the password.
4. An unverified user who attempts login must be routed to a verification recovery screen with a resend option.
5. Resend must enforce cooldown, explain rate limits, and preserve the entered email.
6. If email confirmation is disabled, signup must not force the user into the OTP flow.
7. Duplicate-account handling must remain privacy-safe and must not strand the user waiting for an email that will never arrive.

### R4 — Login

1. Email login must work for a confirmed account created in the same environment.
2. Invalid password, unverified email, network failure, rate limiting, and service failure must have distinct actionable UI states without leaking sensitive account details.
3. Whitespace and email casing must be normalized consistently.
4. Username login must not ship unless its backend dependency is versioned, deployed, security-reviewed, and covered end to end.
5. Recommended release baseline: label the field as **Email** and support email login only until a secure username-login design is approved. Returning an account email from a public username-resolution RPC creates enumeration and privacy risk.

### R5 — Backend contract and environment parity

1. Every RPC invoked by the auth client must exist in migrations, including:
   - `is_username_available`
   - the approved replacement or implementation for username login
   - `sync_current_user_v1`
2. Required migrations and grants must be verified in both staging and production.
3. Auth settings that affect client behavior must be recorded and checked:
   - email confirmation enabled or disabled
   - OTP email template
   - OTP expiry
   - resend/rate limits
   - allowed redirect URLs, if links are supported
4. Database errors during post-verification profile sync must produce a recoverable user state and telemetry rather than silently entering a partially initialized account.

## Security and privacy requirements

- Do not expose service-role credentials in the app or CI artifacts.
- Do not return email addresses from an RPC callable by `anon`.
- Do not log passwords, OTPs, access tokens, refresh tokens, full email addresses, or Supabase keys.
- Use RLS and least-privilege grants for all auth-adjacent tables and functions.
- Keep username enumeration risk bounded through public-profile policy, validation, and rate limiting.
- Persist only the minimum verification recovery state; never persist the password.
- Document database and auth security changes in `docs/engineering/database-and-rls.md` and `docs/engineering/networking-and-auth.md`.

## UX requirements

| Condition | Required user experience |
| --- | --- |
| Username is available | Allow signup to continue |
| Username is taken | “That username is taken. Try another.” |
| Availability service fails | “We couldn’t check that username. Try again.” with retry |
| Account awaits verification | Open verification recovery and allow resend |
| Password is incorrect | Generic incorrect-credentials message |
| Network unavailable | Explain connectivity issue and retain form values |
| Session cannot refresh | Show signed-out recovery once; record diagnostic reason |
| Backend profile sync fails | Show retryable account-setup state |

## Instrumentation

Add privacy-safe events or structured logs for:

- app version/build and an environment label or non-secret project identifier
- auth initial-session outcome
- token refresh success/failure category
- sign-out reason
- install marker state and update versus reinstall classification
- username availability outcome and failure category
- signup accepted/rejected category
- OTP sent, resent, verified, expired, or rate-limited
- login outcome and provider
- profile sync outcome

Dashboards must make it possible to compare authentication success rates by app version and distribution channel without collecting credentials or OTP content.

## Acceptance criteria

### Automated

- Unit tests cover username availability: available, taken, invalid response, network error, missing RPC, and permission error.
- Unit tests cover login error classification, including unverified email and network failure.
- Unit tests cover verification-state restoration without storing a password.
- Unit tests cover initial session events: valid, absent, expired then refreshed, and refresh rejected.
- Database tests cover normalization, case-insensitive uniqueness, concurrent claims, grants, and RLS behavior.
- UI tests cover signup → OTP → authenticated app, relaunch during OTP, resend, email login, and incorrect password.
- CI verifies the production Supabase project identifier in every distributed Release artifact.

### Manual release matrix

Run each journey in staging and production-like distribution builds:

1. Fresh install → signup → OTP → app entry.
2. Signup → terminate before OTP → relaunch → resume verification.
3. Confirmed account → logout → email login.
4. Unconfirmed account → login → recover verification.
5. Authenticated previous build → in-place update → session retained.
6. Authenticated app → delete/reinstall → verify the approved reinstall policy.
7. Offline launch with cached session → reconnect → refresh.
8. Expired/revoked refresh token → clear recovery message.
9. Username availability with available, taken, malformed, and backend-failure cases.
10. Cross-environment credentials → explicit internal diagnostic showing environment mismatch.

Release candidate approval requires all P0 journeys to pass on a physical device and the supported iOS simulator/runtime used by CI.

## Delivery workstreams

1. **Incident confirmation:** capture distribution channel, prior/new build numbers, install method, auth event sequence, install marker, and Supabase project identifier.
2. **Database contract:** design, migrate, secure, deploy, and verify username availability; decide whether username login is removed or implemented through a security-reviewed server boundary.
3. **Client state:** model typed auth errors, persist verification recovery state, and make startup/session refresh deterministic.
4. **Environment controls:** enforce production project selection in distributed builds and add artifact verification.
5. **Quality gates:** add unit, database, and UI tests plus the manual release matrix.
6. **Operations:** add dashboards, sign-out reason monitoring, and an auth incident runbook.

## Release gates

The app is not authentication-ready for release until:

- “Every username is taken” cannot be reproduced and backend failures are differentiated.
- A confirmed new account can log in by email in the distributed production build.
- Verification can be resumed after relaunch.
- In-place update session continuity passes.
- Required RPCs and Auth settings are verified in both Supabase projects.
- P0 automated and manual acceptance tests pass.
- No auth flow exposes email-resolution, token, OTP, or service-role data.

## Decisions required

| Decision | Recommended default | Owner |
| --- | --- | --- |
| Delete/reinstall session policy | Explicit logout is acceptable only if documented; never apply it to an in-place update | TODO |
| Launch login identifier | Email only | TODO |
| Email confirmation mode | Six-digit OTP, matching the current UI | TODO |
| Verification recovery storage | Keychain-backed minimal state | TODO |
| Username normalization | One client/database contract, case-insensitive | TODO |

## Live verification checklist

These items cannot be established from repository code alone:

- Confirm the distributed failing build’s embedded Supabase project.
- Confirm `is_username_available` exists and is callable by the intended role in staging and production.
- Confirm whether any `resolve_login_email` implementation exists outside migrations; remove or security-review it.
- Confirm `sync_current_user_v1` is applied in both projects.
- Confirm email confirmation and OTP template settings in both projects.
- Reproduce the update logout while capturing structured auth and install logs.

## Related code and documentation

- `Spot/Supabase/Supabase.swift`
- `Spot/Services/Auth/AuthViewModel.swift`
- `Spot/Services/AuthService.swift`
- `Spot/Views/Auth/SignupView.swift`
- `Spot/Views/Auth/LoginView.swift`
- `Spot/Views/Auth/ConfirmEmailView.swift`
- `Spot/Utils/FreshInstallDetector.swift`
- `supabase/migrations/20260702120000_sync_current_user_security_definer_v1.sql`
- [Networking and auth](../engineering/networking-and-auth.md)
- [Supabase environment strategy](../engineering/supabase-environment-strategy.md)
- [Database and RLS](../engineering/database-and-rls.md)
- [App launch auth flow](../diagrams/app-launch-auth-flow.md)
