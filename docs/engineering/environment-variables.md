# Environment variables and config secrets

## Purpose

List configuration values the app and backend use, where they live, and whether they are secret.

## Audience

Engineers and infra owners.

## Current status

DEBUG builds select staging defaults in **`Spot/Supabase/Supabase.swift`**. Release builds prefer values injected into **`Spot/Info.plist`** by CI. Edge Function and Azure credentials belong in Supabase function secrets, never the app bundle.

## Details

| Name | Used by | Required | Secret? | Location | Notes |
| --- | --- | --- | --- | --- | --- |
| Supabase **project URL** (staging) | iOS app (DEBUG) | Yes | No (public URL) | `Spot/Supabase/Supabase.swift` → `.staging.url` | Staging/development environment. |
| Supabase **anon / publishable key** (staging) | iOS app (DEBUG) | Yes | Public client credential; protect data with **RLS** | `Spot/Supabase/Supabase.swift` → `.staging.anonKey` | Never ship service-role in the app. |
| Supabase **project URL** (production) | iOS app (RELEASE) | Yes | No (public URL) | Injected by CI/CD from `SUPABASE_PRODUCTION_URL` secret | Production environment. |
| Supabase **anon / publishable key** (production) | iOS app (RELEASE) | Yes | Public client credential; protect data with **RLS** | Injected by CI/CD from `SUPABASE_PRODUCTION_ANON_KEY` secret | Never ship service-role in the app. |
| `SUPABASE_STAGING_URL` | GitHub Actions (deploy.yml) | Optional | No | GitHub repository secrets | Staging project URL; falls back to hardcoded if not set. |
| `SUPABASE_STAGING_ANON_KEY` | GitHub Actions (deploy.yml) | Optional | Yes | GitHub repository secrets | Staging anon key; falls back to hardcoded if not set. |
| `SUPABASE_PRODUCTION_URL` | GitHub Actions (testflight.yml) | **Required** | No | GitHub repository secrets | Production project URL; TestFlight builds fail without this. |
| `SUPABASE_PRODUCTION_ANON_KEY` | GitHub Actions (testflight.yml) | **Required** | Yes | GitHub repository secrets | Production anon key; TestFlight builds fail without this. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server / Edge only | If admin operations | **Yes** | Supabase secrets | **Never** in client. |
| `AZURE_CONTENT_SAFETY_ENDPOINT` | `moderate-image` | Yes | Usually no | Function secret/config in Supabase | Server-side only. |
| `AZURE_CONTENT_SAFETY_KEY` | `moderate-image` | Yes | **Yes** | Function secret in Supabase | Server-side only. |
| `AZURE_CONTENT_SAFETY_API_VERSION` | `moderate-image` | Optional | No | Function config in Supabase | Provider API override. |
| `MODERATION_THRESHOLDS_JSON` | `moderate-image` | Optional | Policy-sensitive | Function config in Supabase | Overrides default category thresholds. |
| `STAGING_TEST_AUTH_ENABLED` | `staging-verify-email` | Staging only | No (kill switch) | Staging function secret | Must be `true`/`1`. **Never** set in production. |
| `STAGING_TEST_AUTH_CODE` | `staging-verify-email` | Optional | **Yes** | Staging function secret | Defaults to `UT1234` when unset. Never ship in the app. |
| `STAGING_TEST_AUTH_EMAILS` | `staging-verify-email` | Optional | Yes (account list) | Staging function secret | When unset/empty, any signup email is allowed on staging. Set to restrict Firebase internal builds. |
| Share / Universal Link config | iOS app | Yes | No | `Info.plist` → `SpotURLs` | Domains must match entitlements. |

### Example placeholders only

```xml
<!-- Do not copy real keys into docs or git history -->
<key>Supabase</key>
<dict>
  <key>url</key>
  <string>https://YOUR_PROJECT.supabase.co</string>
  <key>anonKey</key>
  <string>YOUR_ANON_OR_PUBLISHABLE_KEY</string>
</dict>
```

## Related docs

- [configuration.md](configuration.md)
- [supabase.md](supabase.md)
- [image-moderation.md](image-moderation.md)

## Open questions / TODOs

- Dashboard deployment state and secret presence cannot be proven from source control; verify them during environment smoke tests without copying values into docs.
