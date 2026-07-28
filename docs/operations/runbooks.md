# Runbooks

## Purpose

Short operational procedures for common checks.

## Audience

On-call engineers and release owners.

## Current status

High-level; expand with dashboard deep links as your org standardizes them.

## Details

### Verify Supabase health

- Open Supabase dashboard → project status, database health, Edge Function logs.
- Run a trivial authenticated query from SQL editor with a test user JWT if needed.

### Verify moderation function

- Supabase → Edge Functions → `moderate-image` → invocation logs and error rate.
- Submit a safe test image through a staging build and confirm HTTP 200 with `approved=true`.
- Exercise a policy fixture expecting 422 and a controlled unavailable-provider path expecting retryable 503.
- Confirm the Edge Function, Azure secrets, and Storage promotion are configured separately in staging and production.

### Verify Universal Links

- Device test: open `https://spotapp.online/s/{knownSpotId}`.
- Validate AASA with Apple’s CDN validator or `curl` **without** following redirects incorrectly.

### Verify App Store subscription

- App Store Connect → agreements, tax, banking.
- Sandbox purchase of product id **`spotPro`** (`SpotProProducts.swift`).

### Verify release environment

- `main` / Firebase: confirm embedded project ref is staging (`aeurigbbohyxvtsfiyul`).
- `release/**` / TestFlight: confirm production secrets were injected for `gomdoguewaawdlvijahg`.
- Sign in with an environment-specific account; cross-environment credentials should not work.
- Smoke-test feed, map, Search, profile, deep link, and one controlled moderated publish.

### Check orphan media

- Inspect `media_assets` grouped by `status` and `linked_spot_id`.
- Investigate old `pending`, `failed`, `rejected`, or approved-unlinked rows before deletion.
- Storage objects require separate inspection; deleting a database row does not guarantee blob deletion.
- No scheduled cleanup is defined in this repository, so use a reviewed, environment-specific procedure.

### Safety / moderation incident

- Triage user reports in your support tooling.
- If policy gap, coordinate content takedown via admin tools / DB procedures per [incident-response.md](incident-response.md).

## Related docs

- [../engineering/troubleshooting.md](../engineering/troubleshooting.md)
- [incident-response.md](incident-response.md)

## Open questions / TODOs

- Add org-specific links to dashboards: TODO: confirm with owner.
