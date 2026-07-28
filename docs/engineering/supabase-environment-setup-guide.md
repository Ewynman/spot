# Supabase environment setup guide

## Purpose

Runbook for validating or recreating Spot's staging and production Supabase environments without exposing credentials.

## Audience

Repository administrators, infrastructure owners, and release engineers.

## Current status

Both project routes exist in code:

| Environment | Project ref | Build lane |
| --- | --- | --- |
| Staging | `aeurigbbohyxvtsfiyul` | Local DEBUG and Firebase App Distribution |
| Production | `gomdoguewaawdlvijahg` | TestFlight and App Store |

This repository does not prove deployed schema parity, Edge Function deployment, Auth provider settings, backups, or secret presence. Validate those items in the Supabase and GitHub dashboards.

## Prerequisites

- Supabase access to both projects.
- GitHub repository access to manage Actions secrets.
- Supabase MCP authentication for applying reviewed migrations.
- Apple/Firebase signing configuration appropriate to the distribution lane.

Never copy service-role, Azure, database-password, or private signing values into the repository, terminal transcript, issue, or PR.

## 1. Validate client routing

The environment enum and configuration loader are in [`Spot/Supabase/Supabase.swift`](../../Spot/Supabase/Supabase.swift).

- DEBUG must select `.staging`.
- Release must prefer a complete `Supabase` dictionary from `Info.plist`.
- Firebase workflow injection must target staging.
- TestFlight workflow injection must target production and fail if required values are missing.

Review:

- [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml)
- [`.github/workflows/testflight.yml`](../../.github/workflows/testflight.yml)
- [`Spot/Info.plist`](../../Spot/Info.plist)

Do not add a second environment selector or a separate `SupabaseEnvironment.swift`.

## 2. Configure GitHub Actions

### Firebase / staging lane

| Secret | Requirement |
| --- | --- |
| `SUPABASE_STAGING_URL` | Optional workflow override |
| `SUPABASE_STAGING_ANON_KEY` | Optional workflow override |

The workflow validates the staging project URL before archive.

### TestFlight / production lane

| Secret | Requirement |
| --- | --- |
| `SUPABASE_PRODUCTION_URL` | Required |
| `SUPABASE_PRODUCTION_ANON_KEY` | Required |

These are publishable client values. Data protection still depends on Auth, RLS, grants, and safe RPC definitions. Never configure a service-role key in an iOS build secret.

## 3. Apply schema changes

Migrations live under [`supabase/migrations/`](../../supabase/migrations/).

1. Review SQL for idempotency, RLS, grants, and rollback impact.
2. Resolve the staging project with the Supabase MCP.
3. Apply the migration to staging using `apply_migration`.
4. Run focused staging tests.
5. Resolve the production project and apply the same reviewed migration.
6. Compare migration history and affected objects.

Agents must follow the repository rule requiring MCP application. Do not treat a committed SQL file as deployed.

### Minimum parity query set

Run in each project through an authenticated administrative channel:

```sql
select version, name
from supabase_migrations.schema_migrations
order by version;

select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;

select schemaname, tablename, policyname
from pg_policies
where schemaname in ('public', 'storage')
order by schemaname, tablename, policyname;

select routine_name
from information_schema.routines
where routine_schema = 'public'
order by routine_name;
```

Use counts and object definitions for parity; never export production user rows to staging.

## 4. Validate Storage

Expected buckets include:

| Bucket | Visibility | Current use |
| --- | --- | --- |
| `pending_images` | Private | Pre-moderation uploads |
| `approved_spot_images` | Private | Approved modern Spot images |
| `approved_profile_images` | Private | Intended approved profile images; client not wired |
| `spots` | Private | Legacy Spot image paths |
| `avatars` | Public | Legacy/current profile avatar path |

Apply Storage policies through migrations. Verify an authenticated user can only upload a pending object under their own folder and cannot write an approved bucket.

## 5. Deploy and validate `moderate-image`

The function source is [`supabase/functions/moderate-image/`](../../supabase/functions/moderate-image/).

Configure server-side secrets independently in each project:

- `AZURE_CONTENT_SAFETY_ENDPOINT`
- `AZURE_CONTENT_SAFETY_KEY`
- optional `AZURE_CONTENT_SAFETY_API_VERSION`
- optional `MODERATION_THRESHOLDS_JSON`

The Supabase runtime provides its own URL and service-role context. Do not expose those values to the app.

Validate with an authenticated test user:

1. Create an owned pending `media_assets` row.
2. Upload a safe image to the user's `pending_images` folder.
3. Invoke `moderate-image`.
4. Confirm an approved response promotes the object and records the moderation result.
5. Confirm a policy rejection returns 422 and a provider/config failure returns retryable 503.

Repeat deliberately for each environment; function deployments are project-specific.

## 6. Validate Auth and URLs

For each project, review:

- email/password and Sign in with Apple provider settings;
- confirmation and redirect URLs;
- SMTP/email templates and rate limits;
- Universal Link and custom-scheme return URLs;
- account deletion and session refresh behavior.

Use environment-specific accounts. A staging account should not authenticate against production and vice versa.

## 7. Smoke-test matrix

| Flow | Staging | Production |
| --- | --- | --- |
| Email signup, OTP, login, logout | Required | Focused release smoke |
| Sign in with Apple | Required before release | Focused release smoke |
| Feed, map, Search, profile | Required | Read-only smoke |
| Private profile and block visibility | Required | As needed with controlled accounts |
| Moderated Spot publish | Required | One controlled release smoke |
| Profile avatar | Verify current legacy path and known moderation gap | Avoid changing during smoke |
| Pro entitlement / StoreKit return | Sandbox | TestFlight sandbox |
| Deep-linked Spot | Required | Required |

## 8. Failure and rollback

- If a build embeds the wrong project, stop distribution immediately and follow incident response.
- If a migration fails in staging, fix it with a new reviewed migration before production.
- If production migration partially applies, capture the exact applied state and prefer a forward fix.
- If moderation fails, do not bypass the approval gate; restore function/secrets or pause publishing.
- If schema parity is uncertain, do not promote the release.

## Related docs

- [supabase-environment-strategy.md](supabase-environment-strategy.md)
- [environment-variables.md](environment-variables.md)
- [database-and-rls.md](database-and-rls.md)
- [image-moderation.md](image-moderation.md)
- [ci-cd.md](ci-cd.md)
- [../operations/incident-response.md](../operations/incident-response.md)
