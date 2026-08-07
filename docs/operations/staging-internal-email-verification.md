# Staging internal email verification

## Purpose

Let Xcode DEBUG (and Firebase `INTERNAL_TESTING`) builds verify signup with any made-up email using a fixed staging code (`UT1234` by default), without waiting for email delivery.

## Audience

Engineers and internal QA.

## Setup (staging only)

1. Apply migration `staging_test_auth_attempts_v1` (rate-limit table).
2. Deploy the function:

```sh
./scripts/deploy-staging-verify-email.sh
```

3. Enable on staging (never set on production):

```sh
npx supabase secrets set --project-ref aeurigbbohyxvtsfiyul \
  STAGING_TEST_AUTH_ENABLED=true
```

Optional overrides:

- `STAGING_TEST_AUTH_CODE` — defaults to `UT1234` when unset
- `STAGING_TEST_AUTH_EMAILS` — comma-separated exact emails; when **unset or empty**, **any** signup email is allowed (Xcode dev flow). Set only if you want to lock down Firebase internal builds.

## App usage

1. Run a **DEBUG** Xcode build (staging Supabase).
2. Sign up with any email (e.g. `fakeperson123@test.com`).
3. On Confirm Email → **Use internal test code** → enter `UT1234` (case insensitive).
4. You get a real Supabase session. The normal 6-digit emailed OTP still works too.

## Kill switch

Set `STAGING_TEST_AUTH_ENABLED=false` to disable immediately without an app release.

## Related

- [../product/internal-test-email-verification-prd.md](../product/internal-test-email-verification-prd.md)
- [../engineering/networking-and-auth.md](../engineering/networking-and-auth.md)
- [../engineering/environment-variables.md](../engineering/environment-variables.md)
